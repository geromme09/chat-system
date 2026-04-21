package domain

import (
	"context"
	"time"
)

type Conversation struct {
	ID             string    `json:"id"`
	ParticipantIDs []string  `json:"participant_ids"`
	CreatedAt      time.Time `json:"created_at"`
}

type Message struct {
	ID             string    `json:"id"`
	ConversationID string    `json:"conversation_id"`
	SenderUserID   string    `json:"sender_user_id"`
	Body           string    `json:"body"`
	CreatedAt      time.Time `json:"created_at"`
}

type Repository interface {
	CreateConversation(ctx context.Context, conversation Conversation) error
	ListConversations(ctx context.Context, userID string) ([]Conversation, error)
	GetConversation(ctx context.Context, conversationID string) (Conversation, error)
	CreateMessage(ctx context.Context, message Message) error
	ListMessages(ctx context.Context, conversationID string) ([]Message, error)
}
