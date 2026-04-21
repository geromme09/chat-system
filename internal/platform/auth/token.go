package auth

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"strings"
)

type TokenManager struct {
	secret string
}

func NewTokenManager(secret string) TokenManager {
	return TokenManager{secret: secret}
}

func (m TokenManager) Issue(userID string) string {
	signature := m.sign(userID)
	return base64.RawURLEncoding.EncodeToString([]byte(userID + "." + signature))
}

func (m TokenManager) Parse(token string) (string, error) {
	raw, err := base64.RawURLEncoding.DecodeString(token)
	if err != nil {
		return "", err
	}

	parts := strings.SplitN(string(raw), ".", 2)
	if len(parts) != 2 {
		return "", errors.New("invalid token structure")
	}

	expected := m.sign(parts[0])
	if !hmac.Equal([]byte(parts[1]), []byte(expected)) {
		return "", errors.New("invalid token signature")
	}

	return parts[0], nil
}

func (m TokenManager) sign(value string) string {
	mac := hmac.New(sha256.New, []byte(m.secret))
	mac.Write([]byte(value))
	return hex.EncodeToString(mac.Sum(nil))
}
