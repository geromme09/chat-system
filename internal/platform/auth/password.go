package auth

import (
	"crypto/sha256"
	"encoding/hex"
)

type PasswordHasher struct{}

func (PasswordHasher) Hash(raw string) string {
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}

func (h PasswordHasher) Compare(raw, hashed string) bool {
	return h.Hash(raw) == hashed
}
