package infra

import "time"

type notificationModel struct {
	ID        string
	UserID    string
	Type      string
	Title     string
	Body      string
	Data      []byte
	ReadAt    *time.Time
	CreatedAt time.Time
}

func (notificationModel) TableName() string {
	return "notifications"
}
