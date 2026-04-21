package bootstrap

import (
	"net/http"
	"time"

	chathttp "github.com/geromme09/chat-system/internal/modules/chat/transport/http"
	userhttp "github.com/geromme09/chat-system/internal/modules/user/transport/http"
	"github.com/geromme09/chat-system/internal/platform/auth"
	"github.com/geromme09/chat-system/internal/platform/httpx"
)

func RunHTTP(app *App) error {
	mux := http.NewServeMux()
	tokenManager := auth.NewTokenManager(app.Config.TokenSecret)

	userHandler := userhttp.NewHandler(app.UserService)
	chatHandler := chathttp.NewHandler(app.ChatService)

	mux.HandleFunc("GET /healthz", httpx.Health)
	mux.HandleFunc("POST /api/v1/auth/signup", userHandler.SignUp)
	mux.HandleFunc("POST /api/v1/auth/login", userHandler.Login)
	mux.Handle("GET /api/v1/profile/me", authMiddleware(tokenManager, http.HandlerFunc(userHandler.GetMe)))
	mux.Handle("PUT /api/v1/profile/me", authMiddleware(tokenManager, http.HandlerFunc(userHandler.UpdateMe)))
	mux.Handle("GET /api/v1/chat/conversations", authMiddleware(tokenManager, http.HandlerFunc(chatHandler.ListConversations)))
	mux.Handle("POST /api/v1/chat/conversations", authMiddleware(tokenManager, http.HandlerFunc(chatHandler.CreateConversation)))
	mux.Handle("GET /api/v1/chat/conversations/", authMiddleware(tokenManager, http.HandlerFunc(chatHandler.RouteConversationMessages)))
	mux.Handle("POST /api/v1/chat/conversations/", authMiddleware(tokenManager, http.HandlerFunc(chatHandler.RouteConversationMessages)))

	server := &http.Server{
		Addr:              app.Config.HTTPAddr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	app.Logger.Info("starting http server", "addr", app.Config.HTTPAddr)
	return server.ListenAndServe()
}
