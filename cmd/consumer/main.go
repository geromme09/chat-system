package main

import (
	"context"
	"log"

	appcore "github.com/geromme09/chat-system/internal/app"
)

func main() {
	app, err := appcore.NewApp()
	if err != nil {
		log.Fatal(err)
	}
	defer func() {
		if shutdownErr := app.Shutdown(context.Background()); shutdownErr != nil {
			log.Printf("telemetry shutdown failed: %v", shutdownErr)
		}
	}()

	if err := appcore.RunConsumer(app); err != nil {
		log.Fatal(err)
	}
}
