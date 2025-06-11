# Étape 1: Construction de l'application et du healthchecker
FROM golang:1.24-alpine@sha256:68932fa6d4d4059845c8f40ad7e654e626f3ebd3706eef7846f319293ab5cb7a AS builder

# Définir le répertoire de travail dans le conteneur
WORKDIR /app

# Copier les fichiers go.mod et go.sum pour télécharger les dépendances
COPY go.mod go.sum ./
RUN go mod download

# Copier le reste du code source de l'application (app.go et healthchecker.go)
COPY . .

# Construire l'application Go principale
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o /app/main app.go

# Construire le binaire http_health_pinger
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o /app/http_pinger http_health_pinger.go

# Étape 2: Création de l'image finale légère et sécurisée
FROM gcr.io/distroless/base-debian11:nonroot@sha256:68b0f492c1eb077f71d384b544456dac4afb282372966917df32b3923f65ad0d
# Cette image s'exécute par défaut en tant qu'utilisateur 'nonroot'.

WORKDIR /app

# Copier le binaire de l'application principale
COPY --from=builder /app/main .
# Copier le binaire http_health_pinger
COPY --from=builder /app/http_pinger /http_pinger
# Le binaire doit être exécutable (ce qui est le cas après 'go build').

# Exposer le port sur lequel l'application écoute
EXPOSE 8080

# Commande pour exécuter l'application lorsque le conteneur démarre
# Elle s'exécutera en tant qu'utilisateur 'nonroot'.
CMD ["./main"]

# Healthcheck pour vérifier que l'application répond
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/http_pinger"]
