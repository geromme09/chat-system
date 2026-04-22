package domain

import (
	"context"
	"time"

	userdomain "github.com/geromme09/chat-system/internal/modules/user/domain"
)

const (
	AggregateConversation = "conversation"

	EventMessageCreated  = "chat.message.created"
	EventTypingStarted   = "chat.typing.started"
	EventTypingStopped   = "chat.typing.stopped"
	EventPresenceUpdated = "chat.presence.updated"
	EventPayloadMessage  = "message"

	DirectConversationParticipantCount = 2
	MaxMessageBodyLength               = 2000
	SystemConnectionMessageBody        = "__system_connected__"
)

type Conversation struct {
	ID                  string    `json:"id"`
	ParticipantIDs      []string  `json:"participant_ids"`
	CreatedAt           time.Time `json:"created_at"`
	LastMessageAt       time.Time `json:"last_message_at,omitempty"`
	LastMessageBody     string    `json:"last_message_body"`
	LastMessageSenderID string    `json:"last_message_sender_id"`
	UnreadCount         int64     `json:"unread_count"`
	OtherParticipant    UserCard  `json:"other_participant"`
}

type UserCard struct {
	UserID      string `json:"user_id"`
	Username    string `json:"username"`
	DisplayName string `json:"display_name"`
	AvatarURL   string `json:"avatar_url"`
	City        string `json:"city"`
	IsOnline    bool   `json:"is_online"`
}

type Message struct {
	ID             string     `json:"id"`
	ConversationID string     `json:"conversation_id"`
	SenderUserID   string     `json:"sender_user_id"`
	Body           string     `json:"body"`
	CreatedAt      time.Time  `json:"created_at"`
	ReadAt         *time.Time `json:"read_at,omitempty"`
}

type ConversationReadResult struct {
	ConversationID string `json:"conversation_id"`
	MarkedCount    int64  `json:"marked_count"`
}

type UnreadCount struct {
	Total int64 `json:"total"`
}

type Repository interface {
	CreateConversation(ctx context.Context, conversation Conversation) error
	FindDirectConversation(ctx context.Context, userAID, userBID string) (Conversation, error)
	ListConversations(ctx context.Context, userID string) ([]Conversation, error)
	GetConversation(ctx context.Context, conversationID string) (Conversation, error)
	CreateMessage(ctx context.Context, message Message) error
	ListMessages(ctx context.Context, conversationID, userID string) ([]Message, error)
	MarkConversationRead(ctx context.Context, conversationID, userID string, readAt time.Time) (int64, error)
	GetUnreadCount(ctx context.Context, userID string) (int64, error)
}

func NewUserCard(card userdomain.UserCard) UserCard {
	return UserCard{
		UserID:      card.UserID,
		Username:    card.Username,
		DisplayName: card.DisplayName,
		AvatarURL:   card.AvatarURL,
		City:        card.City,
	}
}
