package response

import (
	"encoding/json"
	"errors"
	"net/http"
)

type ApiResponse struct {
	Code       int               `json:"-"`
	Data       any               `json:"data,omitempty"`
	Error      *ErrorBody        `json:"error,omitempty"`
	Headers    map[string]string `json:"-"`
	TotalCount *int64            `json:"total_count,omitempty"`
	Message    string            `json:"message,omitempty"`
}

type ErrorBody struct {
	Message string `json:"message"`
}

func Ok(data any, totalCount *int64, message ...string) ApiResponse {
	return ApiResponse{
		Code:       http.StatusOK,
		Data:       data,
		Headers:    nil,
		TotalCount: totalCount,
		Message:    optionalMessage(message...),
	}
}

func Created(data any, message ...string) ApiResponse {
	return ApiResponse{
		Code:    http.StatusCreated,
		Data:    data,
		Headers: nil,
		Message: optionalMessage(message...),
	}
}

func NoContent() ApiResponse {
	return ApiResponse{
		Code:    http.StatusNoContent,
		Headers: nil,
	}
}

func Error(status int, message string) ApiResponse {
	if message == "" {
		message = http.StatusText(status)
	}

	return ApiResponse{
		Code: status,
		Error: &ErrorBody{
			Message: message,
		},
	}
}

func BadRequest(err error) ApiResponse {
	return Error(http.StatusBadRequest, errorMessage(err, http.StatusText(http.StatusBadRequest)))
}

func Unauthorized(err error) ApiResponse {
	return Error(http.StatusUnauthorized, errorMessage(err, http.StatusText(http.StatusUnauthorized)))
}

func NotFound(message string) ApiResponse {
	return Error(http.StatusNotFound, message)
}

func InternalServerError(err error) ApiResponse {
	return Error(http.StatusInternalServerError, errorMessage(err, http.StatusText(http.StatusInternalServerError)))
}

func TooManyRequests(err error) ApiResponse {
	return Error(http.StatusTooManyRequests, errorMessage(err, http.StatusText(http.StatusTooManyRequests)))
}

func MethodNotAllowed() ApiResponse {
	return Error(http.StatusMethodNotAllowed, http.StatusText(http.StatusMethodNotAllowed))
}

func RenderJSON(w http.ResponseWriter, res ApiResponse) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	for key, value := range res.Headers {
		w.Header().Set(key, value)
	}

	w.WriteHeader(res.Code)
	if res.Code == http.StatusNoContent {
		return
	}

	enc := json.NewEncoder(w)
	if err := enc.Encode(res); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
}

func WriteJSON(w http.ResponseWriter, status int, data any) {
	RenderJSON(w, ApiResponse{Code: status, Data: data})
}

func WriteError(w http.ResponseWriter, status int, message string) {
	RenderJSON(w, Error(status, message))
}

func optionalMessage(message ...string) string {
	if len(message) == 0 {
		return ""
	}

	return message[0]
}

func errorMessage(err error, fallback string) string {
	if err == nil {
		return fallback
	}

	if errors.Is(err, http.ErrBodyNotAllowed) {
		return fallback
	}

	return err.Error()
}
