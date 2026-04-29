package main

import (
	"context"
	"log"

	_ "github.com/geromme09/chat-system/docs/swagger"
	appcore "github.com/geromme09/chat-system/internal/app"
)

// @title Chat System API
// @version 1.0
// @description FaceOff Social backend API for identity, friends, chat, and notifications.
// @securityDefinitions.apikey BearerAuth
// @in header
// @name Authorization
// @BasePath /

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

	if err := appcore.RunHTTP(app); err != nil {
		log.Fatal(err)
	}
}
