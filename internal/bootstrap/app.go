package bootstrap

import (
	"log/slog"

	"github.com/geromme09/chat-system/internal/modules/chat/app"
	chatinfra "github.com/geromme09/chat-system/internal/modules/chat/infra"
	userapp "github.com/geromme09/chat-system/internal/modules/user/app"
	userinfra "github.com/geromme09/chat-system/internal/modules/user/infra"
	"github.com/geromme09/chat-system/internal/platform/auth"
	"github.com/geromme09/chat-system/internal/platform/config"
	"github.com/geromme09/chat-system/internal/platform/messaging"
	"github.com/geromme09/chat-system/internal/platform/storage"
)

type App struct {
	Config      config.Config
	Logger      *slog.Logger
	UserService *userapp.Service
	ChatService *app.Service
	Publisher   messaging.Publisher
}

func NewApp() (*App, error) {
	cfg := config.Load()
	logger := slog.Default()

	tokenManager := auth.NewTokenManager(cfg.TokenSecret)
	passwordHasher := auth.PasswordHasher{}
	storageService := storage.NewService(cfg.StorageBaseURL)
	userRepo := userinfra.NewMemoryRepository()
	chatRepo := chatinfra.NewMemoryRepository()
	publisher := messaging.NoopPublisher{}

	userService := userapp.NewService(userRepo, passwordHasher, tokenManager, storageService)
	chatService := app.NewService(chatRepo, userRepo, publisher)

	return &App{
		Config:      cfg,
		Logger:      logger,
		UserService: userService,
		ChatService: chatService,
		Publisher:   publisher,
	}, nil
}
