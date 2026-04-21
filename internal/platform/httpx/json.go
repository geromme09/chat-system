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

func Health(w http.ResponseWriter, _ *http.Request) {
	response.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}
