package httpx

import (
	"net/http"

	"github.com/geromme09/chat-system/internal/platform/response"
)

type Context struct {
	ResponseWriter http.ResponseWriter
	Request        *http.Request
}

func NewContext(w http.ResponseWriter, r *http.Request) Context {
	return Context{
		ResponseWriter: w,
		Request:        r,
	}
}

func (c Context) DecodeJSON(target any) error {
	return DecodeJSON(c.Request, target)
}

func (c Context) UserID() (string, bool) {
	return CurrentUserID(c.Request.Context())
}

func (c Context) RequestID() (string, bool) {
	return CurrentRequestID(c.Request.Context())
}

func (c Context) Query(name string) string {
	return c.Request.URL.Query().Get(name)
}

type Handler interface {
	Serve(ctx Context) response.ApiResponse
}

type HandlerFunc func(ctx Context) response.ApiResponse

func (f HandlerFunc) Serve(ctx Context) response.ApiResponse {
	return f(ctx)
}

func MakeHandler(h Handler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := NewContext(w, r)
		res := h.Serve(ctx)
		response.RenderJSON(w, res)
	}
}
