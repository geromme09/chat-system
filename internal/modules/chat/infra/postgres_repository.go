package infra

import (
	"context"
	"errors"
	"time"

	"github.com/geromme09/chat-system/internal/modules/chat/domain"
	"gorm.io/gorm"
)

type PostgresRepository struct {
	db *gorm.DB
}

func NewPostgresRepository(db *gorm.DB) *PostgresRepository {
	return &PostgresRepository{db: db}
}

func (r *PostgresRepository) CreateConversation(ctx context.Context, conversation domain.Conversation) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		model := conversationModel{
			ID:        conversation.ID,
			CreatedAt: conversation.CreatedAt,
		}
		if err := tx.Create(&model).Error; err != nil {
			return err
		}

		participants := make([]conversationParticipantModel, 0, len(conversation.ParticipantIDs))
		for _, participantID := range conversation.ParticipantIDs {
			participants = append(participants, conversationParticipantModel{
				ConversationID: conversation.ID,
				UserID:         participantID,
			})
		}

		return tx.Create(&participants).Error
	})
}

func (r *PostgresRepository) FindDirectConversation(ctx context.Context, userAID, userBID string) (domain.Conversation, error) {
	type conversationRow struct {
		ID        string
		CreatedAt time.Time
	}

	var row conversationRow
	result := r.db.WithContext(ctx).Raw(`
		SELECT conversations.id, conversations.created_at
		FROM conversations
		JOIN conversation_participants participant_a
			ON participant_a.conversation_id = conversations.id
			AND participant_a.user_id = ?
		JOIN conversation_participants participant_b
			ON participant_b.conversation_id = conversations.id
			AND participant_b.user_id = ?
		WHERE (
			SELECT COUNT(*)
			FROM conversation_participants all_participants
			WHERE all_participants.conversation_id = conversations.id
		) = ?
		LIMIT 1
	`, userAID, userBID, domain.DirectConversationParticipantCount).Scan(&row)
	if result.Error != nil {
		return domain.Conversation{}, result.Error
	}
	if result.RowsAffected == 0 {
		return domain.Conversation{}, errors.New("conversation not found")
	}

	return r.GetConversation(ctx, row.ID)
}

func (r *PostgresRepository) ListConversations(ctx context.Context, userID string) ([]domain.Conversation, error) {
	type row struct {
		ID                  string
		CreatedAt           time.Time
		LastMessageAt       *time.Time
		LastMessageBody     string
		LastMessageSenderID string
		UnreadCount         int64
		OtherUserID         string
		OtherUsername       string
		OtherDisplayName    string
		OtherAvatarURL      string
		OtherCity           string
	}

	rows := make([]row, 0)
	if err := r.db.WithContext(ctx).Raw(`
		SELECT
			conversations.id,
			conversations.created_at,
			last_message.created_at AS last_message_at,
			COALESCE(last_message.body, '') AS last_message_body,
			COALESCE(last_message.sender_user_id, '') AS last_message_sender_id,
			COALESCE(unread.unread_count, 0) AS unread_count,
			other_users.id AS other_user_id,
			other_users.username AS other_username,
			other_profiles.display_name AS other_display_name,
			other_profiles.avatar_url AS other_avatar_url,
			other_profiles.city AS other_city
		FROM conversations
		JOIN conversation_participants self_participant
			ON self_participant.conversation_id = conversations.id
			AND self_participant.user_id = ?
		JOIN conversation_participants other_participant
			ON other_participant.conversation_id = conversations.id
			AND other_participant.user_id <> ?
		JOIN users other_users ON other_users.id = other_participant.user_id
		JOIN user_profiles other_profiles ON other_profiles.user_id = other_users.id
		LEFT JOIN LATERAL (
			SELECT messages.created_at, messages.body, messages.sender_user_id
			FROM messages
			WHERE messages.conversation_id = conversations.id
			ORDER BY messages.created_at DESC
			LIMIT 1
		) last_message ON TRUE
		LEFT JOIN LATERAL (
			SELECT COUNT(*) AS unread_count
			FROM messages
			LEFT JOIN message_reads
				ON message_reads.message_id = messages.id
				AND message_reads.user_id = ?
			WHERE messages.conversation_id = conversations.id
				AND messages.sender_user_id <> ?
				AND message_reads.message_id IS NULL
		) unread ON TRUE
		ORDER BY COALESCE(last_message.created_at, conversations.created_at) DESC
	`, userID, userID, userID, userID).Scan(&rows).Error; err != nil {
		return nil, err
	}

	conversations := make([]domain.Conversation, 0, len(rows))
	for _, row := range rows {
		conversation := domain.Conversation{
			ID:                  row.ID,
			ParticipantIDs:      []string{userID, row.OtherUserID},
			CreatedAt:           row.CreatedAt,
			LastMessageBody:     row.LastMessageBody,
			LastMessageSenderID: row.LastMessageSenderID,
			UnreadCount:         row.UnreadCount,
			OtherParticipant: domain.UserCard{
				UserID:      row.OtherUserID,
				Username:    row.OtherUsername,
				DisplayName: row.OtherDisplayName,
				AvatarURL:   row.OtherAvatarURL,
				City:        row.OtherCity,
			},
		}
		if row.LastMessageAt != nil {
			conversation.LastMessageAt = *row.LastMessageAt
		}
		conversations = append(conversations, conversation)
	}

	return conversations, nil
}

func (r *PostgresRepository) GetConversation(ctx context.Context, conversationID string) (domain.Conversation, error) {
	var model conversationModel
	if err := r.db.WithContext(ctx).Where("id = ?", conversationID).First(&model).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return domain.Conversation{}, errors.New("conversation not found")
		}
		return domain.Conversation{}, err
	}

	var participants []conversationParticipantModel
	if err := r.db.WithContext(ctx).
		Where("conversation_id = ?", conversationID).
		Order("user_id ASC").
		Find(&participants).Error; err != nil {
		return domain.Conversation{}, err
	}

	conversation := domain.Conversation{
		ID:             model.ID,
		ParticipantIDs: make([]string, 0, len(participants)),
		CreatedAt:      model.CreatedAt,
	}
	for _, participant := range participants {
		conversation.ParticipantIDs = append(conversation.ParticipantIDs, participant.UserID)
	}

	return conversation, nil
}

func (r *PostgresRepository) CreateMessage(ctx context.Context, message domain.Message) error {
	model := messageModel{
		ID:             message.ID,
		ConversationID: message.ConversationID,
		SenderUserID:   message.SenderUserID,
		Body:           message.Body,
		CreatedAt:      message.CreatedAt,
	}

	return r.db.WithContext(ctx).Create(&model).Error
}

func (r *PostgresRepository) ListMessages(ctx context.Context, conversationID, userID string) ([]domain.Message, error) {
	type row struct {
		ID             string
		ConversationID string
		SenderUserID   string
		Body           string
		CreatedAt      time.Time
		ReadAt         *time.Time
	}

	rows := make([]row, 0)
	if err := r.db.WithContext(ctx).Raw(`
		SELECT
			messages.id,
			messages.conversation_id,
			messages.sender_user_id,
			messages.body,
			messages.created_at,
			message_reads.read_at
		FROM messages
		LEFT JOIN message_reads
			ON message_reads.message_id = messages.id
			AND message_reads.user_id = ?
		WHERE messages.conversation_id = ?
		ORDER BY messages.created_at ASC, messages.id ASC
	`, userID, conversationID).Scan(&rows).Error; err != nil {
		return nil, err
	}

	messages := make([]domain.Message, 0, len(rows))
	for _, row := range rows {
		messages = append(messages, domain.Message{
			ID:             row.ID,
			ConversationID: row.ConversationID,
			SenderUserID:   row.SenderUserID,
			Body:           row.Body,
			CreatedAt:      row.CreatedAt,
			ReadAt:         row.ReadAt,
		})
	}

	return messages, nil
}

func (r *PostgresRepository) MarkConversationRead(ctx context.Context, conversationID, userID string, readAt time.Time) (int64, error) {
	result := r.db.WithContext(ctx).Exec(`
		INSERT INTO message_reads (message_id, user_id, read_at)
		SELECT messages.id, ?, ?
		FROM messages
		LEFT JOIN message_reads
			ON message_reads.message_id = messages.id
			AND message_reads.user_id = ?
		WHERE messages.conversation_id = ?
			AND messages.sender_user_id <> ?
			AND message_reads.message_id IS NULL
	`, userID, readAt, userID, conversationID, userID)
	if result.Error != nil {
		return 0, result.Error
	}

	return result.RowsAffected, nil
}

func (r *PostgresRepository) GetUnreadCount(ctx context.Context, userID string) (int64, error) {
	type row struct {
		Total int64
	}

	var result row
	if err := r.db.WithContext(ctx).Raw(`
		SELECT COUNT(*) AS total
		FROM messages
		JOIN conversation_participants
			ON conversation_participants.conversation_id = messages.conversation_id
			AND conversation_participants.user_id = ?
		LEFT JOIN message_reads
			ON message_reads.message_id = messages.id
			AND message_reads.user_id = ?
		WHERE messages.sender_user_id <> ?
			AND message_reads.message_id IS NULL
	`, userID, userID, userID).Scan(&result).Error; err != nil {
		return 0, err
	}

	return result.Total, nil
}
