package storage

import (
	"fmt"
	"strings"
)

type Service struct {
	baseURL string
}

func NewService(baseURL string) Service {
	return Service{baseURL: strings.TrimSuffix(baseURL, "/")}
}

func (s Service) AvatarURL(fileName string) string {
	return fmt.Sprintf("%s/avatars/%s", s.baseURL, fileName)
}
