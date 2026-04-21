package config

import "os"

type Config struct {
	Env            string
	HTTPAddr       string
	TokenSecret    string
	PostgresDSN    string
	RabbitMQURL    string
	StorageBaseURL string
}

func Load() Config {
	return Config{
		Env:            getEnv("APP_ENV", "development"),
		HTTPAddr:       getEnv("HTTP_ADDR", ":8080"),
		TokenSecret:    getEnv("TOKEN_SECRET", "change-me"),
		PostgresDSN:    getEnv("POSTGRES_DSN", ""),
		RabbitMQURL:    getEnv("RABBITMQ_URL", ""),
		StorageBaseURL: getEnv("STORAGE_BASE_URL", "https://cdn.example.com"),
	}
}

func getEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}

	return fallback
}
