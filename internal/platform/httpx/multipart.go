package httpx

import (
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"strings"
)

const defaultMultipartMemory = 16 << 20

func IsMultipart(r *http.Request) bool {
	return strings.HasPrefix(strings.ToLower(strings.TrimSpace(r.Header.Get("Content-Type"))), "multipart/form-data")
}

func ParseMultipart(r *http.Request) error {
	return r.ParseMultipartForm(defaultMultipartMemory)
}

func FormString(r *http.Request, key string) string {
	return strings.TrimSpace(r.FormValue(key))
}

func FileDataURL(r *http.Request, field string) (string, error) {
	file, header, err := r.FormFile(field)
	if err != nil {
		if errors.Is(err, http.ErrMissingFile) {
			return "", nil
		}
		return "", err
	}
	defer file.Close()

	return multipartFileDataURL(file, header)
}

func multipartFileDataURL(file multipart.File, header *multipart.FileHeader) (string, error) {
	contentType := strings.TrimSpace(header.Header.Get("Content-Type"))
	if contentType == "" {
		contentType = "image/jpeg"
	}
	if !strings.HasPrefix(contentType, "image/") {
		return "", errors.New("uploaded file must be an image")
	}

	bytes, err := io.ReadAll(file)
	if err != nil {
		return "", err
	}
	if len(bytes) == 0 {
		return "", errors.New("uploaded file is empty")
	}

	return fmt.Sprintf("data:%s;base64,%s", contentType, base64.StdEncoding.EncodeToString(bytes)), nil
}
