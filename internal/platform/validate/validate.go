package validate

import (
	"reflect"
	"strings"
	"sync"

	"github.com/go-playground/validator/v10"
)

var (
	once     sync.Once
	instance *validator.Validate
)

func Struct(input any) error {
	return validatorInstance().Struct(input)
}

func validatorInstance() *validator.Validate {
	once.Do(func() {
		validate := validator.New(validator.WithRequiredStructEnabled())
		validate.RegisterTagNameFunc(func(field reflect.StructField) string {
			name := field.Tag.Get("json")
			if name == "" {
				return strings.ToLower(field.Name)
			}

			name = strings.TrimSpace(strings.Split(name, ",")[0])
			if name == "" || name == "-" {
				return strings.ToLower(field.Name)
			}

			return name
		})
		instance = validate
	})

	return instance
}
