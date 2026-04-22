package infra

import "time"

type conversationModel struct {
	ID        string `gorm:"primaryKey"`
	CreatedAt time.Time
}

func (conversationModel) TableName() string {
	return "conversations"
}

type conversationParticipantModel struct {
	ConversationID string `gorm:"primaryKey"`
	UserID         string `gorm:"primaryKey"`
}

func (conversationParticipantModel) TableName() string {
	return "conversation_participants"
}

type messageModel struct {
	ID             string `gorm:"primaryKey"`
	ConversationID string
	SenderUserID   string
	Body           string
	CreatedAt      time.Time
}

func (messageModel) TableName() string {
	return "messages"
}

type messageReadModel struct {
	MessageID string `gorm:"primaryKey"`
	UserID    string `gorm:"primaryKey"`
	ReadAt    time.Time
}

func (messageReadModel) TableName() string {
	return "message_reads"
}
