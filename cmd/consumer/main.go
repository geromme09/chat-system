package main

import (
	"log"

	"github.com/geromme09/chat-system/internal/bootstrap"
)

func main() {
	app, err := bootstrap.NewApp()
	if err != nil {
		log.Fatal(err)
	}

	if err := bootstrap.RunConsumer(app); err != nil {
		log.Fatal(err)
	}
}
