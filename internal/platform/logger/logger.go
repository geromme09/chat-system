package logger

import (
	"log/slog"
	"os"
	"strings"

	"github.com/geromme09/chat-system/internal/platform/config"
)

func New(cfg config.Config) *slog.Logger {
	options := &slog.HandlerOptions{
		AddSource: false,
		Level:     slog.LevelInfo,
	}

	if strings.EqualFold(cfg.LogFormat, "json") {
		return slog.New(slog.NewJSONHandler(os.Stdout, options))
	}

	return slog.New(slog.NewTextHandler(os.Stdout, options))
}
