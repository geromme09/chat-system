package infra

import "time"

type userModel struct {
	ID              string `gorm:"primaryKey"`
	Email           string
	PasswordHash    string
	AccountStatus   string
	AuthProvider    string
	IsVerified      bool
	ProfileComplete bool
	CreatedAt       time.Time
}

func (userModel) TableName() string {
	return "users"
}

type profileModel struct {
	UserID       string `gorm:"primaryKey"`
	DisplayName  string
	Bio          string
	AvatarURL    string
	City         string
	Country      string
	SkillLevel   string
	Visible      bool
	LastModified time.Time
}

func (profileModel) TableName() string {
	return "user_profiles"
}

type userSportModel struct {
	UserID    string `gorm:"primaryKey"`
	SportName string `gorm:"primaryKey"`
}

func (userSportModel) TableName() string {
	return "user_sports"
}
