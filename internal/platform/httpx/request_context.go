package httpx

import "context"

type contextKey string

const userIDContextKey contextKey = "userID"
const requestIDContextKey contextKey = "requestID"

func WithUserID(ctx context.Context, userID string) context.Context {
	return context.WithValue(ctx, userIDContextKey, userID)
}

func CurrentUserID(ctx context.Context) (string, bool) {
	value, ok := ctx.Value(userIDContextKey).(string)
	return value, ok
}

func WithRequestID(ctx context.Context, requestID string) context.Context {
	return context.WithValue(ctx, requestIDContextKey, requestID)
}

func CurrentRequestID(ctx context.Context) (string, bool) {
	value, ok := ctx.Value(requestIDContextKey).(string)
	return value, ok
}
