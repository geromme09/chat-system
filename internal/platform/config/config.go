package config

import (
	"os"
	"strconv"
)

type Config struct {
	Env                    string
	HTTPAddr               string
	HTTPLogEnabled         bool
	LogFormat              string
	LogBodyDebug           bool
	LogBodyMaxBytes        int
	SQLLogDebug            bool
	SQLSlowThresholdMS     int
	TokenSecret            string
	PostgresDSN            string
	PostgresMaxOpenConns   int
	PostgresMaxIdleConns   int
	PostgresConnMaxIdleMin int
	PostgresConnMaxLifeMin int
	RabbitMQURL            string
	RedisAddr              string
	RedisPassword          string
	RedisDB                int
	RedisPoolSize          int
	RedisMinIdleConns      int
	StorageBaseURL         string
	RateLimitRequestsPerS  int
	RateLimitBurst         int
}

func Load() Config {
	env := normalizeEnv(getEnv("APP_ENV", "dev"))

	return Config{
		Env:                    env,
		HTTPAddr:               getEnv("HTTP_ADDR", ":8080"),
		HTTPLogEnabled:         getEnvBool("HTTP_LOG_ENABLED", defaultHTTPLogEnabled(env)),
		LogFormat:              getEnv("LOG_FORMAT", defaultLogFormat(env)),
		LogBodyDebug:           getEnvBool("LOG_BODY_DEBUG", defaultLogBodyDebug(env)),
		LogBodyMaxBytes:        getEnvInt("LOG_BODY_MAX_BYTES", 4096),
		SQLLogDebug:            getEnvBool("SQL_LOG_DEBUG", defaultSQLLogDebug(env)),
		SQLSlowThresholdMS:     getEnvInt("SQL_SLOW_THRESHOLD_MS", 200),
		TokenSecret:            getEnv("TOKEN_SECRET", "change-me"),
		PostgresDSN:            getEnv("POSTGRES_DSN", ""),
		PostgresMaxOpenConns:   getEnvInt("POSTGRES_MAX_OPEN_CONNS", 25),
		PostgresMaxIdleConns:   getEnvInt("POSTGRES_MAX_IDLE_CONNS", 10),
		PostgresConnMaxIdleMin: getEnvInt("POSTGRES_CONN_MAX_IDLE_MINUTES", 15),
		PostgresConnMaxLifeMin: getEnvInt("POSTGRES_CONN_MAX_LIFETIME_MINUTES", 60),
		RabbitMQURL:            getEnv("RABBITMQ_URL", ""),
		RedisAddr:              getEnv("REDIS_ADDR", ""),
		RedisPassword:          getEnv("REDIS_PASSWORD", ""),
		RedisDB:                getEnvInt("REDIS_DB", 0),
		RedisPoolSize:          getEnvInt("REDIS_POOL_SIZE", 10),
		RedisMinIdleConns:      getEnvInt("REDIS_MIN_IDLE_CONNS", 2),
		StorageBaseURL:         getEnv("STORAGE_BASE_URL", "https://cdn.example.com"),
		RateLimitRequestsPerS:  getEnvInt("RATE_LIMIT_REQUESTS_PER_SECOND", 5),
		RateLimitBurst:         getEnvInt("RATE_LIMIT_BURST", 15),
	}
}

func normalizeEnv(value string) string {
	switch value {
	case "dev", "development", "":
		return "dev"
	case "staging", "stage":
		return "staging"
	case "prod", "production":
		return "prod"
	default:
		return "dev"
	}
}

func defaultHTTPLogEnabled(env string) bool {
	switch env {
	case "dev", "prod":
		return true
	default:
		return false
	}
}

func defaultLogFormat(env string) string {
	switch env {
	case "prod", "staging":
		return "json"
	default:
		return "text"
	}
}

func defaultLogBodyDebug(env string) bool {
	return env == "dev"
}

func defaultSQLLogDebug(env string) bool {
	return env == "dev"
}

func getEnvBool(key string, fallback bool) bool {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}

	parsed, err := strconv.ParseBool(value)
	if err != nil {
		return fallback
	}

	return parsed
}

func getEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}

	return fallback
}

func getEnvInt(key string, fallback int) int {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}

	parsed, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}

	return parsed
}
