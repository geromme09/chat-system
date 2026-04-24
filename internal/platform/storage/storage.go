package storage

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"mime"
	"os"
	"path/filepath"
	"strings"

	"github.com/geromme09/chat-system/internal/platform/identity"
)

const maxFeedImageBytes = 8 * 1024 * 1024

type Service struct {
	baseURL  string
	localDir string
}

func NewService(baseURL string, localDir ...string) Service {
	dir := "var/storage"
	if len(localDir) > 0 && strings.TrimSpace(localDir[0]) != "" {
		dir = strings.TrimSpace(localDir[0])
	}

	return Service{
		baseURL:  strings.TrimSuffix(baseURL, "/"),
		localDir: dir,
	}
}

func (s Service) AvatarURL(fileName string) string {
	return fmt.Sprintf("%s/avatars/%s", s.baseURL, fileName)
}

func (s Service) SaveFeedImageDataURL(ctx context.Context, dataURL string) (string, error) {
	mediaType, payload, ok := strings.Cut(strings.TrimSpace(dataURL), ",")
	if !ok {
		return "", errors.New("invalid image data URL")
	}

	mimeType := strings.TrimPrefix(mediaType, "data:")
	mimeType = strings.TrimSuffix(mimeType, ";base64")
	if !strings.HasPrefix(mimeType, "image/") || !strings.HasSuffix(mediaType, ";base64") {
		return "", errors.New("image_data_url must be a base64 image data URL")
	}

	bytes, err := base64.StdEncoding.DecodeString(payload)
	if err != nil {
		return "", errors.New("invalid image data")
	}
	if len(bytes) == 0 {
		return "", errors.New("image data is empty")
	}
	if len(bytes) > maxFeedImageBytes {
		return "", errors.New("image is too large")
	}

	extension := extensionForMime(mimeType)
	fileName := identity.NewUUID() + extension
	relativePath := filepath.Join("feed", fileName)
	targetPath := filepath.Join(s.localDir, relativePath)

	select {
	case <-ctx.Done():
		return "", ctx.Err()
	default:
	}

	if err := os.MkdirAll(filepath.Dir(targetPath), 0o755); err != nil {
		return "", err
	}
	if err := os.WriteFile(targetPath, bytes, 0o644); err != nil {
		return "", err
	}

	select {
	case <-ctx.Done():
		return "", ctx.Err()
	default:
	}

	return s.MediaURL(filepath.ToSlash(relativePath)), nil
}

func (s Service) MediaURL(relativePath string) string {
	relativePath = strings.TrimLeft(strings.TrimSpace(relativePath), "/")
	if relativePath == "" {
		return ""
	}

	return fmt.Sprintf("%s/media/%s", s.baseURL, relativePath)
}

func (s Service) LocalDir() string {
	return s.localDir
}

func extensionForMime(mimeType string) string {
	if extensions, err := mime.ExtensionsByType(mimeType); err == nil && len(extensions) > 0 {
		return extensions[0]
	}

	switch mimeType {
	case "image/png":
		return ".png"
	case "image/webp":
		return ".webp"
	case "image/gif":
		return ".gif"
	default:
		return ".jpg"
	}
}
