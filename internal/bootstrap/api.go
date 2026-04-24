package bootstrap

import (
	"net/http"
	"strings"
	"time"

	chathttp "github.com/geromme09/chat-system/internal/modules/chat/transport/http"
	chatws "github.com/geromme09/chat-system/internal/modules/chat/transport/ws"
	feedhttp "github.com/geromme09/chat-system/internal/modules/feed/transport/http"
	notificationhttp "github.com/geromme09/chat-system/internal/modules/notification/transport/http"
	userdomain "github.com/geromme09/chat-system/internal/modules/user/domain"
	userhttp "github.com/geromme09/chat-system/internal/modules/user/transport/http"
	"github.com/geromme09/chat-system/internal/platform/auth"
	"github.com/geromme09/chat-system/internal/platform/httpx"
	"github.com/geromme09/chat-system/internal/platform/response"
	httpSwagger "github.com/swaggo/http-swagger"
)

func RunHTTP(app *App) error {
	mux := http.NewServeMux()
	tokenManager := auth.NewTokenManager(app.Config.TokenSecret)
	chatWSHandler := chatws.NewHandler(tokenManager, app.ChatHub)
	limiter := newRateLimiter(app.Config.RateLimitRequestsPerS, app.Config.RateLimitBurst)

	mux.HandleFunc("GET /healthz", httpx.Health)
	mux.Handle("GET /swagger/", httpSwagger.WrapHandler)
	mux.Handle("GET /media/", http.StripPrefix("/media/", http.FileServer(http.Dir(app.Config.StorageLocalDir))))
	mux.Handle("GET /ws/chat", chatWSHandler)
	mux.HandleFunc("POST /api/v1/auth/signup", httpx.MakeHandler(userhttp.NewSignUpHandler(app.UserService)))
	mux.HandleFunc("POST /api/v1/auth/login", httpx.MakeHandler(userhttp.NewLoginHandler(app.UserService)))
	mux.Handle("GET /api/v1/profile/me", authMiddleware(tokenManager, httpx.MakeHandler(userhttp.NewGetMeHandler(app.UserService))))
	mux.Handle("PUT /api/v1/profile/me", authMiddleware(tokenManager, httpx.MakeHandler(userhttp.NewUpdateMeHandler(app.UserService))))
	mux.Handle("GET /api/v1/profile/", authMiddleware(tokenManager, httpx.MakeHandler(userhttp.NewGetProfileHandler(app.UserService))))
	mux.Handle("GET /api/v1/users/search", authMiddleware(tokenManager, httpx.MakeHandler(userhttp.NewSearchUsersHandler(app.UserService))))
	mux.Handle("POST /api/v1/friends/requests", authMiddleware(tokenManager, httpx.MakeHandler(userhttp.NewSendFriendRequestHandler(app.UserService))))
	mux.Handle("GET /api/v1/friends/requests/incoming", authMiddleware(tokenManager, httpx.MakeHandler(userhttp.NewIncomingFriendRequestsHandler(app.UserService))))
	mux.Handle("GET /api/v1/notifications", authMiddleware(tokenManager, httpx.MakeHandler(notificationhttp.NewHandler(app.NotificationService))))
	mux.Handle("POST /api/v1/notifications/read-all", authMiddleware(tokenManager, httpx.MakeHandler(notificationhttp.NewHandler(app.NotificationService))))
	mux.Handle("POST /api/v1/notifications/", authMiddleware(tokenManager, httpx.MakeHandler(notificationhttp.NewHandler(app.NotificationService))))
	mux.Handle("POST /api/v1/friends/requests/", authMiddleware(tokenManager, httpx.MakeHandler(httpx.HandlerFunc(func(ctx httpx.Context) response.ApiResponse {
		if strings.HasSuffix(ctx.Request.URL.Path, "/accept") {
			return userhttp.NewRespondFriendRequestHandler(app.UserService, userdomain.FriendRequestStatusAccepted).Serve(ctx)
		}
		if strings.HasSuffix(ctx.Request.URL.Path, "/decline") {
			return userhttp.NewRespondFriendRequestHandler(app.UserService, userdomain.FriendRequestStatusDeclined).Serve(ctx)
		}
		return response.NotFound("resource not found")
	}))))
	mux.Handle("GET /api/v1/friends", authMiddleware(tokenManager, httpx.MakeHandler(userhttp.NewListFriendsHandler(app.UserService))))
	mux.Handle("GET /api/v1/chat/conversations", authMiddleware(tokenManager, httpx.MakeHandler(chathttp.NewListConversationsHandler(app.ChatService))))
	mux.Handle("POST /api/v1/chat/conversations", authMiddleware(tokenManager, httpx.MakeHandler(chathttp.NewCreateConversationHandler(app.ChatService))))
	mux.Handle("GET /api/v1/chat/unread-count", authMiddleware(tokenManager, httpx.MakeHandler(chathttp.NewUnreadCountHandler(app.ChatService))))
	mux.Handle("GET /api/v1/chat/conversations/", authMiddleware(tokenManager, httpx.MakeHandler(chathttp.NewConversationDetailHandler(app.ChatService))))
	mux.Handle("POST /api/v1/chat/conversations/", authMiddleware(tokenManager, httpx.MakeHandler(chathttp.NewConversationDetailHandler(app.ChatService))))
	mux.Handle("GET /api/v1/feed", authMiddleware(tokenManager, httpx.MakeHandler(feedhttp.NewHandler(app.FeedService, app.UserService))))
	mux.Handle("POST /api/v1/feed", authMiddleware(tokenManager, httpx.MakeHandler(feedhttp.NewHandler(app.FeedService, app.UserService))))
	mux.Handle("GET /api/v1/feed/", authMiddleware(tokenManager, httpx.MakeHandler(feedhttp.NewHandler(app.FeedService, app.UserService))))
	mux.Handle("POST /api/v1/feed/", authMiddleware(tokenManager, httpx.MakeHandler(feedhttp.NewHandler(app.FeedService, app.UserService))))

	handler := limiter.middleware(mux)
	if app.Config.HTTPLogEnabled {
		handler = requestLoggingMiddleware(app.Logger, app.Config.LogBodyDebug, app.Config.LogBodyMaxBytes, handler)
	}

	server := &http.Server{
		Addr:              app.Config.HTTPAddr,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
	}

	app.Logger.Info("starting http server", "addr", app.Config.HTTPAddr)
	return server.ListenAndServe()
}
