package validate

import (
	"errors"
	"strings"
)

func Required(value, field string) error {
	if strings.TrimSpace(value) == "" {
		return errors.New(field + " is required")
	}

	return nil
}

func MinLength(value string, length int, field string) error {
	if len(strings.TrimSpace(value)) < length {
		return errors.New(field + " must be at least the minimum length")
	}

	return nil
}
