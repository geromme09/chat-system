package main

import (
	"context"
	"log"

	"github.com/geromme09/chat-system/internal/bootstrap"
)

func main() {
	app, err := bootstrap.NewApp()
	if err != nil {
		log.Fatal(err)
	}
	defer func() {
		if shutdownErr := app.Shutdown(context.Background()); shutdownErr != nil {
			log.Printf("telemetry shutdown failed: %v", shutdownErr)
		}
	}()

	if err := bootstrap.RunConsumer(app); err != nil {
		log.Fatal(err)
	}
}
