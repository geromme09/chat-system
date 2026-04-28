package bootstrap

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	chatapp "github.com/geromme09/chat-system/internal/modules/chat/app"
	chatinfra "github.com/geromme09/chat-system/internal/modules/chat/infra"
	chatws "github.com/geromme09/chat-system/internal/modules/chat/transport/ws"
	feedapp "github.com/geromme09/chat-system/internal/modules/feed/app"
	feedinfra "github.com/geromme09/chat-system/internal/modules/feed/infra"
	notificationapp "github.com/geromme09/chat-system/internal/modules/notification/app"
	notificationinfra "github.com/geromme09/chat-system/internal/modules/notification/infra"
	userapp "github.com/geromme09/chat-system/internal/modules/user/app"
	userinfra "github.com/geromme09/chat-system/internal/modules/user/infra"
	"github.com/geromme09/chat-system/internal/platform/auth"
	"github.com/geromme09/chat-system/internal/platform/config"
	appLogger "github.com/geromme09/chat-system/internal/platform/logger"
	"github.com/geromme09/chat-system/internal/platform/messaging"
	"github.com/geromme09/chat-system/internal/platform/storage"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	gormLogger "gorm.io/gorm/logger"
)

type App struct {
	Config              config.Config
	DB                  *gorm.DB
	Logger              *slog.Logger
	UserService         *userapp.Service
	ChatService         *chatapp.Service
	FeedService         *feedapp.Service
	NotificationService *notificationapp.Service
	ChatHub             *chatws.Hub
	Publisher           messaging.Publisher
}

func NewApp() (*App, error) {
	cfg := config.Load()
	logger := appLogger.New(cfg)
	db, err := openPostgres(cfg)
	if err != nil {
		return nil, err
	}

	tokenManager := auth.NewTokenManager(cfg.TokenSecret)
	passwordHasher := auth.PasswordHasher{}
	storageService, err := storage.NewService(storage.Config{
		BaseURL:       cfg.StorageBaseURL,
		Driver:        cfg.StorageDriver,
		LocalDir:      cfg.StorageLocalDir,
		PublicBaseURL: cfg.StoragePublicBaseURL,
		S3: storage.S3Config{
			Endpoint:      cfg.StorageS3Endpoint,
			PublicBaseURL: cfg.StoragePublicBaseURL,
			AccessKeyID:   cfg.StorageS3AccessKey,
			SecretKey:     cfg.StorageS3SecretKey,
			UseSSL:        cfg.StorageS3UseSSL,
			Region:        cfg.StorageS3Region,
			ProfileBucket: cfg.StorageS3ProfileBucket,
			PostBucket:    cfg.StorageS3PostBucket,
		},
	})
	if err != nil {
		return nil, err
	}
	userRepo := userinfra.NewPostgresRepository(db, storageService)
	chatRepo := chatinfra.NewPostgresRepository(db, storageService)
	feedRepo := feedinfra.NewPostgresRepository(db, storageService)
	notificationRepo := notificationinfra.NewPostgresRepository(db)
	chatHub := chatws.NewHub(logger, chatRepo)
	publisher := messaging.NoopPublisher{}
	notificationFactory := notificationapp.NewStaticChannelFactory(chatHub)
	notificationService := notificationapp.NewService(notificationRepo, notificationFactory)

	chatService := chatapp.NewService(chatRepo, userRepo, publisher, chatHub)
	feedService := feedapp.NewService(feedRepo, storageService, notificationService)
	userService := userapp.NewService(userRepo, passwordHasher, tokenManager, storageService, publisher, notificationService, chatService)

	return &App{
		Config:              cfg,
		DB:                  db,
		Logger:              logger,
		UserService:         userService,
		ChatService:         chatService,
		FeedService:         feedService,
		NotificationService: notificationService,
		ChatHub:             chatHub,
		Publisher:           publisher,
	}, nil
}

func openPostgres(cfg config.Config) (*gorm.DB, error) {
	if cfg.PostgresDSN == "" {
		return nil, errors.New("POSTGRES_DSN is required")
	}

	db, err := gorm.Open(postgres.Open(cfg.PostgresDSN), &gorm.Config{
		TranslateError: true,
		Logger:         newGormLogger(cfg),
	})
	if err != nil {
		return nil, fmt.Errorf("open postgres: %w", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, fmt.Errorf("get postgres sql db: %w", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if err := sqlDB.PingContext(ctx); err != nil {
		return nil, fmt.Errorf("ping postgres: %w", err)
	}

	sqlDB.SetMaxOpenConns(cfg.PostgresMaxOpenConns)
	sqlDB.SetMaxIdleConns(cfg.PostgresMaxIdleConns)
	sqlDB.SetConnMaxIdleTime(time.Duration(cfg.PostgresConnMaxIdleMin) * time.Minute)
	sqlDB.SetConnMaxLifetime(time.Duration(cfg.PostgresConnMaxLifeMin) * time.Minute)

	return db, nil
}

func newGormLogger(cfg config.Config) gormLogger.Interface {
	level := gormLogger.Silent
	if cfg.SQLLogDebug {
		level = gormLogger.Info
	}

	return gormLogger.New(
		gormLogWriter{logger: slog.Default()},
		gormLogger.Config{
			SlowThreshold:             time.Duration(cfg.SQLSlowThresholdMS) * time.Millisecond,
			LogLevel:                  level,
			IgnoreRecordNotFoundError: true,
			Colorful:                  false,
		},
	)
}

type gormLogWriter struct {
	logger *slog.Logger
}

func (w gormLogWriter) Printf(format string, args ...any) {
	w.logger.Info(fmt.Sprintf(format, args...))
}
