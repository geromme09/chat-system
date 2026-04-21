package bootstrap

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/geromme09/chat-system/internal/modules/chat/app"
	chatinfra "github.com/geromme09/chat-system/internal/modules/chat/infra"
	sportapp "github.com/geromme09/chat-system/internal/modules/sport/app"
	sportinfra "github.com/geromme09/chat-system/internal/modules/sport/infra"
	userapp "github.com/geromme09/chat-system/internal/modules/user/app"
	userinfra "github.com/geromme09/chat-system/internal/modules/user/infra"
	"github.com/geromme09/chat-system/internal/platform/auth"
	"github.com/geromme09/chat-system/internal/platform/config"
	appLogger "github.com/geromme09/chat-system/internal/platform/logger"
	"github.com/geromme09/chat-system/internal/platform/messaging"
	"github.com/geromme09/chat-system/internal/platform/storage"
	"github.com/redis/go-redis/v9"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	gormLogger "gorm.io/gorm/logger"
)

type App struct {
	Config       config.Config
	DB           *gorm.DB
	Logger       *slog.Logger
	UserService  *userapp.Service
	SportService *sportapp.Service
	ChatService  *app.Service
	Publisher    messaging.Publisher
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
	storageService := storage.NewService(cfg.StorageBaseURL)
	userRepo := userinfra.NewPostgresRepository(db)
	chatRepo := chatinfra.NewMemoryRepository()
	publisher := messaging.NoopPublisher{}
	sportRepo := sportinfra.NewPostgresRepository(db)
	sportCache := sportCache(cfg)

	userService := userapp.NewService(userRepo, passwordHasher, tokenManager, storageService)
	sportsService := sportapp.NewService(sportRepo, sportCache)
	chatService := app.NewService(chatRepo, userRepo, publisher)

	return &App{
		Config:       cfg,
		DB:           db,
		Logger:       logger,
		UserService:  userService,
		SportService: sportsService,
		ChatService:  chatService,
		Publisher:    publisher,
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

func sportCache(cfg config.Config) sportapp.Cache {
	if cfg.RedisAddr == "" {
		return nil
	}

	client := redis.NewClient(&redis.Options{
		Addr:         cfg.RedisAddr,
		Password:     cfg.RedisPassword,
		DB:           cfg.RedisDB,
		PoolSize:     cfg.RedisPoolSize,
		MinIdleConns: cfg.RedisMinIdleConns,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if err := client.Ping(ctx).Err(); err != nil {
		return nil
	}

	return sportinfra.NewRedisCache(client)
}
