package infra

import "time"

type userModel struct {
	ID              string `gorm:"primaryKey"`
	Email           string
	Username        string
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
	AvatarBucket string
	AvatarKey    string
	AvatarType   string
	City         string
	Country      string
	Gender       string
	HobbiesText  string
	Visible      bool
	LastModified time.Time
}

func (profileModel) TableName() string {
	return "user_profiles"
}

type friendshipModel struct {
	ID              string
	RequesterUserID string
	AddresseeUserID string
	Status          string
	SeenAt          *time.Time
	CreatedAt       time.Time
	UpdatedAt       time.Time
}

func (friendshipModel) TableName() string {
	return "friendships"
}
