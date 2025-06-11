# Guide de Test des Endpoints de l'API Go

Ce document décrit comment tester les différents endpoints de l'application Go conteneurisée pour s'assurer de son bon fonctionnement.

## Prérequis

- L'application et la base de données PostgreSQL doivent être en cours d'exécution via Docker Compose. Si ce n'est pas le cas, lancez-les avec la commande :
  ```bash
  docker compose up --build -d
  ```
- `curl` doit être installé sur votre machine pour exécuter les commandes de test.

## 1. Test de l'Endpoint de Santé (`/_internal/health`)

Cet endpoint permet de vérifier rapidement si l'application est démarrée et répond.

**Commande :**
```bash
curl -i http://localhost:8080/_internal/health
```

**Explication de la commande `curl -i` :**
- `curl` : Outil en ligne de commande pour transférer des données avec des URLs.
- `-i` (ou `--include`) : Demande à `curl` d'inclure les en-têtes de la réponse HTTP dans la sortie. C'est utile pour voir le code de statut HTTP et d'autres métadonnées.
- `http://localhost:8080/_internal/health` : L'URL de l'endpoint de santé de notre application.

**Résultat attendu :**
```
HTTP/1.1 200 OK
Date: Wed, 11 Jun 2025 08:16:24 GMT
Content-Length: 0
```
**Interprétation du résultat :**
- `HTTP/1.1 200 OK` : Indique que le serveur a reçu la requête, l'a traitée avec succès et a renvoyé une réponse positive. C'est le signe que l'application est saine.
- `Content-Length: 0` : Signifie que le corps de la réponse est vide. Pour cet endpoint de santé, c'est un comportement normal et attendu, car il suffit de savoir que le service répond.

## 2. Test de l'Endpoint des Utilisateurs (`/api/users`)

Cet endpoint permet de gérer les utilisateurs (les lister et en ajouter).

### 2.1. Lister les utilisateurs (GET)

Permet de récupérer la liste de tous les utilisateurs.

**Commande :**
```bash
curl http://localhost:8080/api/users
```

**Résultat attendu (initialement, si la base est vide) :**
```json
{"users":[]}
```
**Interprétation :**
- Le serveur répond avec un JSON contenant une clé `"users"` et un tableau vide `[]`, indiquant qu'aucun utilisateur n'est encore enregistré.

### 2.2. Ajouter un nouvel utilisateur (POST)

Permet d'ajouter un nouvel utilisateur à la base de données.

**Commande :**
```bash
curl -X POST -H "Content-Type: application/json" -d '{"name":"John Doe"}' http://localhost:8080/api/users
```
**Explication de la commande :**
- `-X POST` : Spécifie que la méthode HTTP à utiliser est POST.
- `-H "Content-Type: application/json"` : Définit l'en-tête `Content-Type` pour indiquer que le corps de la requête est au format JSON.
- `-d '{"name":"John Doe"}'` : Fournit les données (le *payload*) de la requête, ici un objet JSON avec le nom de l'utilisateur à créer.
- `http://localhost:8080/api/users` : L'URL de l'endpoint pour ajouter des utilisateurs.

**Résultat attendu :**
```json
{"id":1,"name":"John Doe"}
```
**Interprétation :**
- Le serveur répond avec un JSON représentant l'utilisateur qui vient d'être créé, incluant son `id` (généré par la base de données, ici `1`) et son `name`.
- Un code de statut `201 Created` est également renvoyé (visible avec `curl -i`).

### 2.3. Lister les utilisateurs après ajout (GET)

Pour vérifier que l'utilisateur a bien été ajouté.

**Commande :**
```bash
curl http://localhost:8080/api/users
```

**Résultat attendu (après avoir ajouté "John Doe") :**
```json
{"users":[{"id":1,"name":"John Doe"}]}
```
**Interprétation :**
- Le serveur répond maintenant avec un JSON contenant l'utilisateur "John Doe" dans la liste, confirmant que l'opération d'ajout a réussi et que les données sont persistées.

## Conclusion

Ces tests permettent de valider le bon fonctionnement des principales fonctionnalités de l'API : la disponibilité du service, la lecture de données (GET) et l'écriture de données (POST) en interaction avec la base de données.