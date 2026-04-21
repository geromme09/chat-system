package auth

import "golang.org/x/crypto/bcrypt"

type PasswordHasher struct{}

func (PasswordHasher) Hash(raw string) (string, error) {
	hashed, err := bcrypt.GenerateFromPassword([]byte(raw), bcrypt.DefaultCost)
	if err != nil {
		return "", err
	}

	return string(hashed), nil
}

func (h PasswordHasher) Compare(raw, hashed string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hashed), []byte(raw)) == nil
}
