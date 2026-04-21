package httpx

import "context"

type contextKey string

const userIDContextKey contextKey = "userID"

func WithUserID(ctx context.Context, userID string) context.Context {
	return context.WithValue(ctx, userIDContextKey, userID)
}

func CurrentUserID(ctx context.Context) (string, bool) {
	value, ok := ctx.Value(userIDContextKey).(string)
	return value, ok
}
