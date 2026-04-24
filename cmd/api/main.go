package main

import (
	"log"

	_ "github.com/geromme09/chat-system/docs/swagger"
	"github.com/geromme09/chat-system/internal/bootstrap"
)

// @title Chat System API
// @version 1.0
// @description FaceOff Social backend API for identity, friends, chat, and notifications.
// @securityDefinitions.apikey BearerAuth
// @in header
// @name Authorization
// @BasePath /

func main() {
	app, err := bootstrap.NewApp()
	if err != nil {
		log.Fatal(err)
	}

	if err := bootstrap.RunHTTP(app); err != nil {
		log.Fatal(err)
	}
}
