# --- Étape 1: L'environnement de compilation (Builder) ---
# Utilise une image Go officielle basée sur Alpine Linux comme base pour la compilation.
# Le tag est épinglé avec un digest SHA256 pour garantir des builds reproductibles.
# L'étape est nommée 'builder' pour pouvoir y faire référence plus tard.
FROM golang:1.24-alpine@sha256:68932fa6d4d4059845c8f40ad7e654e626f3ebd3706eef7846f319293ab5cb7a AS builder

# Définit le répertoire de travail par défaut à '/app' à l'intérieur du conteneur.
# Toutes les commandes suivantes (COPY, RUN, etc.) seront exécutées depuis ce répertoire.
WORKDIR /app

# Copie les fichiers de gestion des dépendances Go dans le conteneur.
# Cette étape est séparée pour tirer parti du cache Docker : si ces fichiers ne changent pas,
# la couche de téléchargement des dépendances ne sera pas reconstruite.
COPY go.mod go.sum ./

# Télécharge toutes les dépendances listées dans go.mod et les met en cache.
# Cette commande est exécutée uniquement si go.mod ou go.sum ont changé.
RUN go mod download

# Installe 'air', un outil de live-reloading pour le développement Go.
# Ceci n'affecte pas l'image de production car il est dans l'étape 'builder'.
RUN go install github.com/air-verse/air@latest

# Copie tout le reste du code source du projet (fichiers .go, etc.) dans le conteneur.
COPY . .

# Compile le fichier app.go pour créer le binaire principal de l'application.
# CGO_ENABLED=0 : Désactive CGO pour créer un binaire statique, portable et sans dépendances C.
# GOOS=linux : Spécifie que le binaire doit être compilé pour un système d'exploitation Linux.
# -o /app/main : Spécifie le nom et l'emplacement du fichier de sortie.
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o /app/main app.go

# Compile le fichier http_health_pinger.go pour créer le binaire du health check.
# Les mêmes options de compilation sont utilisées pour garantir un binaire statique.
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o /app/http_pinger http_health_pinger.go


# --- Étape 2: L'image finale de production ---
# Utilise une image "distroless" de Google comme base.
# Cette image est minimale : elle ne contient que le strict nécessaire pour exécuter une application
# (pas de shell, pas de gestionnaire de paquets), ce qui la rend très légère et sécurisée.
# La variante ':nonroot' s'exécute par défaut avec un utilisateur non-privilégié.
FROM gcr.io/distroless/base-debian11:nonroot@sha256:68b0f492c1eb077f71d384b544456dac4afb282372966917df32b3923f65ad0d

# Définit le répertoire de travail par défaut à '/app' dans l'image finale.
WORKDIR /app

# Copie uniquement le binaire compilé de l'application principale depuis l'étape 'builder'.
# Le chemin '--from=builder /app/main' indique la source, et '.' la destination ('/app/main').
COPY --from=builder /app/main .

# Copie uniquement le binaire compilé du health check depuis l'étape 'builder'.
# Le binaire est copié à la racine pour un accès simple par la commande HEALTHCHECK.
COPY --from=builder /app/http_pinger /http_pinger

# Informe Docker que le conteneur écoute sur le port 8080 au moment de l'exécution.
# C'est une métadonnée ; cela n'expose pas réellement le port. L'exposition se fait dans docker-compose.yml.
EXPOSE 8080

# Définit la commande à exécuter lorsque le conteneur démarre.
# Ici, il s'agit simplement de lancer le binaire principal de l'application.
CMD ["./main"]

# Définit une instruction de vérification de santé pour le conteneur.
# Docker exécutera périodiquement la commande spécifiée pour vérifier si le conteneur est sain.
# --interval=15s : Vérifie toutes les 15 secondes.
# --timeout=3s : Considère la vérification comme échouée si elle prend plus de 3 secondes.
# --start-period=5s : Ne commence les vérifications qu'après 5 secondes pour laisser le temps à l'app de démarrer.
# --retries=3 : Le conteneur est marqué comme 'unhealthy' après 3 échecs consécutifs.
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  # La commande à exécuter pour le health check : notre binaire http_pinger à l'intérieur du container
  CMD ["/http_pinger"]
