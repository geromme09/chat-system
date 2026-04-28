package httpx

import (
	"encoding/json"
	"net/http"

	"github.com/geromme09/chat-system/internal/platform/response"
)

func DecodeJSON(r *http.Request, target any) error {
	defer r.Body.Close()
	return json.NewDecoder(r.Body).Decode(target)
}

// Health reports API process health.
// @Summary Health check
// @Tags system
// @Produce json
// @Success 200 {object} response.ApiResponse
// @Router /healthz [get]
func Health(w http.ResponseWriter, _ *http.Request) {
	response.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}
