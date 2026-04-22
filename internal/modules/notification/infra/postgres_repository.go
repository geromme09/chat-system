package infra

import (
	"context"
	"encoding/json"
	"time"

	notificationdomain "github.com/geromme09/chat-system/internal/modules/notification/domain"
	"gorm.io/gorm"
)

type PostgresRepository struct {
	db *gorm.DB
}

func NewPostgresRepository(db *gorm.DB) *PostgresRepository {
	return &PostgresRepository{db: db}
}

func (r *PostgresRepository) Create(ctx context.Context, notification notificationdomain.Notification) (notificationdomain.Notification, error) {
	data, err := json.Marshal(notification.Data)
	if err != nil {
		return notificationdomain.Notification{}, err
	}

	model := notificationModel{
		ID:        notification.ID,
		UserID:    notification.UserID,
		Type:      notification.Type,
		Title:     notification.Title,
		Body:      notification.Body,
		Data:      data,
		ReadAt:    notification.ReadAt,
		CreatedAt: notification.CreatedAt,
	}
	if err := r.db.WithContext(ctx).Create(&model).Error; err != nil {
		return notificationdomain.Notification{}, err
	}

	return notification, nil
}

func (r *PostgresRepository) ListByUser(ctx context.Context, userID string, offset, limit int) ([]notificationdomain.Notification, error) {
	var models []notificationModel
	if err := r.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("created_at DESC").
		Offset(offset).
		Limit(limit).
		Find(&models).Error; err != nil {
		return nil, err
	}

	notifications := make([]notificationdomain.Notification, 0, len(models))
	for _, model := range models {
		data := map[string]any{}
		if len(model.Data) > 0 {
			if err := json.Unmarshal(model.Data, &data); err != nil {
				return nil, err
			}
		}
		notifications = append(notifications, notificationdomain.Notification{
			ID:        model.ID,
			UserID:    model.UserID,
			Type:      model.Type,
			Title:     model.Title,
			Body:      model.Body,
			Data:      data,
			ReadAt:    model.ReadAt,
			CreatedAt: model.CreatedAt,
		})
	}

	return notifications, nil
}

func (r *PostgresRepository) MarkAllRead(ctx context.Context, userID string, readAt time.Time) error {
	return r.db.WithContext(ctx).
		Model(&notificationModel{}).
		Where("user_id = ? AND read_at IS NULL", userID).
		Update("read_at", readAt).Error
}

func (r *PostgresRepository) MarkRead(ctx context.Context, userID, notificationID string, readAt time.Time) error {
	return r.db.WithContext(ctx).
		Model(&notificationModel{}).
		Where("id = ? AND user_id = ? AND read_at IS NULL", notificationID, userID).
		Update("read_at", readAt).Error
}
