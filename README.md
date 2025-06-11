# Application Go Conteneurisée avec PostgreSQL et Health Check HTTP

Ce projet démontre comment conteneuriser une application Go qui interagit avec une base de données PostgreSQL, en utilisant Docker et Docker Compose. Il met en œuvre une stratégie de health check HTTP robuste, même avec des images Docker `distroless`.

## Architecture

L'application est composée des éléments suivants :

- **Application Go (`app.go`)** : Une API REST simple avec des endpoints pour gérer des utilisateurs et un endpoint de santé (`/_internal/health`).
- **Base de données PostgreSQL** : Un service PostgreSQL lancé via Docker Compose.
- **`http_health_pinger.go`** : Un petit programme Go dédié, compilé en un binaire statique. Son unique rôle est d'effectuer une requête HTTP GET à l'endpoint `/_internal/health` de l'application principale. Il est utilisé par l'instruction `HEALTHCHECK` du `Dockerfile` pour déterminer la santé de l'application.
- **`Dockerfile`** : Un Dockerfile multi-étapes optimisé :
    - Étape de build (`builder`) basée sur `golang:1.24-alpine` pour compiler l'application Go (`main`) et le `http_pinger`.
    - Étape finale basée sur `gcr.io/distroless/base-debian11:nonroot` pour une image légère et sécurisée, ne contenant que les binaires nécessaires.
- **`docker-compose.yml`** : Orchestre le lancement de l'application Go et du service PostgreSQL, configure les réseaux, les volumes et les variables d'environnement.
- **`.env`** : Fichier pour stocker les variables d'environnement (identifiants de base de données, ports).
- **`.dockerignore`** : Exclut les fichiers inutiles du contexte de build Docker.

## Stratégie de Health Check

L'application Go expose un endpoint `/_internal/health` qui, lorsqu'il est appelé, vérifie la connectivité à la base de données en effectuant un `ping`.

Pour les images `distroless` qui ne contiennent pas d'outils comme `curl` ou `wget`, nous ne pouvons pas directement appeler cet endpoint HTTP depuis l'instruction `HEALTHCHECK` du `Dockerfile`.

La solution adoptée ici est d'utiliser `http_health_pinger.go` :
1. Ce petit programme est compilé en un binaire statique (`http_pinger`) dans l'étape de build du `Dockerfile`.
2. Le binaire `http_pinger` est copié dans l'image `distroless` finale.
3. L'instruction `HEALTHCHECK` dans le `Dockerfile` exécute `/http_pinger`.
4. `http_pinger` fait une requête GET à `http://localhost:8080/_internal/health` (l'application principale écoutant sur ce port à l'intérieur du conteneur).
5. Si la requête réussit avec un statut `200 OK`, `http_pinger` se termine avec un code de sortie `0` (indiquant la santé).
6. En cas d'erreur ou de statut non-`200 OK`, `http_pinger` se termine avec un code de sortie `1` (indiquant une défaillance).

Cette approche permet d'avoir un health check HTTP complet tout en bénéficiant de la sécurité et de la légèreté des images `distroless`.

## Prérequis

- Docker et Docker Compose installés.

## Lancement de l'application

1. Clonez ce dépôt (si ce n'est pas déjà fait).
2. Placez-vous à la racine du projet.
3. Pour démarrer les conteneurs (cela construira les images lors du premier lancement si elles n'existent pas) :
   ```bash
   docker compose up -d
   ```
   Si vous avez modifié le code source (par exemple, `app.go`, `http_health_pinger.go`) ou le `Dockerfile` et que vous souhaitez forcer la reconstruction des images avant de démarrer, utilisez :
   ```bash
   docker compose up --build -d
   ```

## Tester l'application

Une fois les conteneurs démarrés et sains (vérifiez avec `docker compose ps`), vous pouvez tester les endpoints :

- **Health Check de l'application** (depuis votre machine hôte) :
  ```bash
  curl -i http://localhost:8080/_internal/health
  ```
  Devrait retourner `HTTP/1.1 200 OK`.

- **Lister les utilisateurs** :
  ```bash
  curl http://localhost:8080/api/users
  ```
  Devrait retourner `{"users":[]}` initialement.

- **Ajouter un utilisateur** :
  ```bash
  curl -X POST -H "Content-Type: application/json" -d '{"name":"Test User"}' http://localhost:8080/api/users
  ```
  Devrait retourner `{"id":1,"name":"Test User"}` (l'ID peut varier).

- **Vérifier la liste après ajout** :
  ```bash
  curl http://localhost:8080/api/users
  ```
  Devrait maintenant inclure l'utilisateur ajouté.

Consultez `documentation/healthy-check.md` pour des explications plus détaillées sur les tests.

## Arrêter l'application

Pour arrêter et supprimer les conteneurs, le réseau et les volumes anonymes :
```bash
docker compose down
```
Pour arrêter sans supprimer les volumes nommés (afin de conserver les données PostgreSQL) :
```bash
docker compose stop
```
