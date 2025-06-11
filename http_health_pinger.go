// http_health_pinger.go est un petit programme utilitaire conçu pour être utilisé
// par l'instruction HEALTHCHECK dans un Dockerfile, en particulier avec des images
// minimalistes comme distroless qui ne contiennent pas d'outils tels que curl ou wget.
// Il effectue une requête HTTP GET à l'endpoint de santé spécifié (par défaut
// http://localhost:8080/_internal/health de l'application principale) et se termine
// avec un code de sortie 0 si la réponse est HTTP 200 OK, ou 1 dans le cas contraire.
// Cela permet un health check HTTP robuste pour les applications conteneurisées.

package main

import (
	"fmt"
	"net/http"
	"os"
	"time"
)

func main() {
	// L'endpoint de santé de notre application principale
	healthEndpointURL := "http://localhost:8080/_internal/health"

	client := http.Client{
		Timeout: 2 * time.Second, // Timeout pour la requête HTTP
	}

	resp, err := client.Get(healthEndpointURL)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error making GET request to %s: %v\n", healthEndpointURL, err)
		os.Exit(1)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		fmt.Println("Health check successful: Received 200 OK")
		os.Exit(0) // Succès
	} else {
		fmt.Fprintf(os.Stderr, "Health check failed: Received status code %d from %s\n", resp.StatusCode, healthEndpointURL)
		os.Exit(1) // Échec
	}
}
