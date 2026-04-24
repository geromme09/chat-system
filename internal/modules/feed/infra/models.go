package infra

import "time"

type feedPostModel struct {
	ID           string `gorm:"primaryKey"`
	AuthorUserID string
	PostType     string
	Caption      string
	CreatedAt    time.Time
}

func (feedPostModel) TableName() string {
	return "feed_posts"
}

type feedMediaModel struct {
	ID         string `gorm:"primaryKey"`
	FeedPostID string
	MediaType  string
	MediaURL   string
	CreatedAt  time.Time
}

func (feedMediaModel) TableName() string {
	return "feed_media"
}

type feedReactionModel struct {
	FeedPostID string `gorm:"primaryKey"`
	UserID     string `gorm:"primaryKey"`
	CreatedAt  time.Time
}

func (feedReactionModel) TableName() string {
	return "feed_reactions"
}

type feedCommentModel struct {
	ID              string `gorm:"primaryKey"`
	FeedPostID      string
	ParentCommentID *string
	AuthorUserID    string
	Body            string
	CreatedAt       time.Time
}

func (feedCommentModel) TableName() string {
	return "feed_comments"
}
