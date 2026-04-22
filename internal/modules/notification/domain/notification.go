package domain

import (
	"context"
	"time"
)

const (
	TypeFriendRequestReceived = "friend_request_received"
	TypeFriendRequestAccepted = "friend_request_accepted"
	TypeFriendRequestDeclined = "friend_request_declined"

	EventNotificationCreated = "notification.created"
)

type Notification struct {
	ID        string         `json:"id"`
	UserID    string         `json:"user_id"`
	Type      string         `json:"type"`
	Title     string         `json:"title"`
	Body      string         `json:"body"`
	Data      map[string]any `json:"data"`
	ReadAt    *time.Time     `json:"read_at,omitempty"`
	CreatedAt time.Time      `json:"created_at"`
}

type Page struct {
	Items    []Notification `json:"items"`
	Page     int            `json:"page"`
	Limit    int            `json:"limit"`
	NextPage *int           `json:"next_page,omitempty"`
}

type Repository interface {
	Create(ctx context.Context, notification Notification) (Notification, error)
	ListByUser(ctx context.Context, userID string, offset, limit int) ([]Notification, error)
	MarkRead(ctx context.Context, userID, notificationID string, readAt time.Time) error
	MarkAllRead(ctx context.Context, userID string, readAt time.Time) error
}
