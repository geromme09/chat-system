package bootstrap

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
	"go.uber.org/zap"

	chathttp "github.com/geromme09/chat-system/internal/modules/chat/transport/http"
	chatws "github.com/geromme09/chat-system/internal/modules/chat/transport/ws"
	feedhttp "github.com/geromme09/chat-system/internal/modules/feed/transport/http"
	notificationhttp "github.com/geromme09/chat-system/internal/modules/notification/transport/http"
	userdomain "github.com/geromme09/chat-system/internal/modules/user/domain"
	userhttp "github.com/geromme09/chat-system/internal/modules/user/transport/http"
	"github.com/geromme09/chat-system/internal/platform/auth"
	"github.com/geromme09/chat-system/internal/platform/httpx"
	"github.com/geromme09/chat-system/internal/platform/observability"
	"github.com/geromme09/chat-system/internal/platform/response"
	httpSwagger "github.com/swaggo/http-swagger"
)

func RunHTTP(app *App) error {
	gin.SetMode(gin.ReleaseMode)

	router := gin.New()
	router.Use(gin.Recovery())
	if app.Config.MetricsEnabled {
		router.Use(observability.MetricsMiddleware())
	}
	if app.Config.ObservabilityEnabled && app.Config.TracingEnabled {
		router.Use(otelgin.Middleware(
			app.Config.ObservabilitySvcName,
			otelgin.WithFilter(func(r *http.Request) bool {
				switch r.URL.Path {
				case "/health", "/healthz", "/metrics":
					return false
				default:
					return true
				}
			}),
		))
	}

	tokenManager := auth.NewTokenManager(app.Config.TokenSecret)
	chatWSHandler := chatws.NewHandler(tokenManager, app.ChatHub)
	limiter := newRateLimiter(app.Config.RateLimitRequestsPerS, app.Config.RateLimitBurst)

	router.GET("/healthz", func(c *gin.Context) {
		httpx.Health(c.Writer, c.Request)
	})
	router.GET("/metrics", observability.MetricsHandler())
	router.GET("/swagger/*any", gin.WrapH(httpSwagger.WrapHandler))
	router.GET("/media/*filepath", gin.WrapH(http.StripPrefix("/media/", http.FileServer(http.Dir(app.Config.StorageLocalDir)))))
	router.GET("/ws/chat", gin.WrapH(chatWSHandler))

	authGroup := router.Group("/")
	authGroup.Use(ginAuthMiddleware(tokenManager))

	router.POST("/api/v1/auth/signup", ginResponse(userhttp.NewSignUpHandler(app.UserService).Handle))
	router.POST("/api/v1/auth/login", ginResponse(userhttp.NewLoginHandler(app.UserService).Handle))

	profile := authGroup.Group("/api/v1/profile")
	profile.GET("/me", ginResponse(userhttp.NewGetMeHandler(app.UserService).Handle))
	profile.PUT("/me", ginResponse(userhttp.NewUpdateMeHandler(app.UserService).Handle))
	profile.GET("/:userID", ginResponse(userhttp.NewGetProfileHandler(app.UserService).Handle))

	users := authGroup.Group("/api/v1/users")
	users.GET("/search", ginResponse(userhttp.NewSearchUsersHandler(app.UserService).Handle))

	friends := authGroup.Group("/api/v1/friends")
	friends.GET("", ginResponse(userhttp.NewListFriendsHandler(app.UserService).Handle))
	friends.POST("/requests", ginResponse(userhttp.NewSendFriendRequestHandler(app.UserService).Handle))
	friends.GET("/requests/incoming", ginResponse(userhttp.NewIncomingFriendRequestsHandler(app.UserService).Handle))
	friends.POST("/requests/:id/accept", ginResponse(userhttp.NewRespondFriendRequestHandler(app.UserService, userdomain.FriendRequestStatusAccepted).Handle))
	friends.POST("/requests/:id/decline", ginResponse(userhttp.NewRespondFriendRequestHandler(app.UserService, userdomain.FriendRequestStatusDeclined).Handle))

	notifications := authGroup.Group("/api/v1/notifications")
	notifications.GET("", ginResponse(notificationhttp.NewListNotificationsHandler(app.NotificationService).Handle))
	notifications.POST("/read-all", ginResponse(notificationhttp.NewMarkAllReadHandler(app.NotificationService).Handle))
	notifications.POST("/:id/read", ginResponse(notificationhttp.NewMarkNotificationReadHandler(app.NotificationService).Handle))

	chat := authGroup.Group("/api/v1/chat")
	chat.GET("/unread-count", ginResponse(chathttp.NewUnreadCountHandler(app.ChatService).Handle))
	chat.GET("/conversations", ginResponse(chathttp.NewListConversationsHandler(app.ChatService).Handle))
	chat.POST("/conversations", ginResponse(chathttp.NewCreateConversationHandler(app.ChatService).Handle))
	chat.GET("/conversations/:id/messages", ginResponse(chathttp.NewListConversationMessagesHandler(app.ChatService).Handle))
	chat.POST("/conversations/:id/messages", ginResponse(chathttp.NewSendConversationMessageHandler(app.ChatService).Handle))
	chat.POST("/conversations/:id/read", ginResponse(chathttp.NewMarkConversationReadHandler(app.ChatService).Handle))

	feed := authGroup.Group("/api/v1/feed")
	feed.GET("", ginResponse(feedhttp.NewListPostsHandler(app.FeedService).Handle))
	feed.POST("", ginResponse(feedhttp.NewCreatePostHandler(app.FeedService, app.UserService).Handle))
	feed.GET("/:id", ginResponse(feedhttp.NewGetPostHandler(app.FeedService).Handle))
	feed.PUT("/:id", ginResponse(feedhttp.NewUpdatePostHandler(app.FeedService).Handle))
	feed.PATCH("/:id", ginResponse(feedhttp.NewUpdatePostHandler(app.FeedService).Handle))
	feed.DELETE("/:id", ginResponse(feedhttp.NewDeletePostHandler(app.FeedService).Handle))
	feed.POST("/:id/react", ginResponse(feedhttp.NewToggleReactionHandler(app.FeedService).Handle))
	feed.POST("/:id/like", ginResponse(feedhttp.NewLikePostHandler(app.FeedService).Handle))
	feed.DELETE("/:id/like", ginResponse(feedhttp.NewUnlikePostHandler(app.FeedService).Handle))
	feed.POST("/:id/hide", ginResponse(feedhttp.NewHidePostHandler(app.FeedService).Handle))
	feed.POST("/:id/report", ginResponse(feedhttp.NewReportPostHandler(app.FeedService).Handle))
	feed.GET("/:id/comments", ginResponse(feedhttp.NewListCommentsHandler(app.FeedService).Handle))
	feed.POST("/:id/comments", ginResponse(feedhttp.NewCreateCommentHandler(app.FeedService, app.UserService).Handle))

	var handler http.Handler = router
	handler = limiter.middleware(handler)
	if app.Config.HTTPLogEnabled {
		handler = requestLoggingMiddleware(app.Logger, app.Config.LogBodyDebug, app.Config.LogBodyMaxBytes, handler)
	}

	server := &http.Server{
		Addr:              app.Config.HTTPAddr,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
	}

	app.Logger.Info("starting http server", zap.String("addr", app.Config.HTTPAddr))
	return server.ListenAndServe()
}

func ginAuthMiddleware(tokenManager auth.TokenManager) gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if len(header) < 8 || header[:7] != "Bearer " {
			response.WriteError(c.Writer, http.StatusUnauthorized, "missing or invalid bearer token")
			c.Abort()
			return
		}

		userID, err := tokenManager.Parse(header[7:])
		if err != nil {
			response.WriteError(c.Writer, http.StatusUnauthorized, "invalid bearer token")
			c.Abort()
			return
		}

		c.Request = c.Request.WithContext(httpx.WithUserID(c.Request.Context(), userID))
		c.Next()
	}
}

func ginResponse(handler func(*gin.Context) response.ApiResponse) gin.HandlerFunc {
	return func(c *gin.Context) {
		res := handler(c)
		response.RenderJSON(c.Writer, res)
		c.Abort()
	}
}
