package infra

import (
	"context"
	"errors"
	"time"

	"github.com/geromme09/chat-system/internal/modules/feed/domain"
	"github.com/geromme09/chat-system/internal/platform/identity"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type PostgresRepository struct {
	db *gorm.DB
}

type feedPostRow struct {
	ID                    string
	AuthorUserID          string
	Username              string
	DisplayName           string
	AvatarURL             string
	City                  string
	PostType              string
	Caption               string
	ImageURL              string
	ReactionCount         int64
	CommentCount          int64
	ReactedByMe           bool
	CreatedAt             time.Time
	FriendshipStatus      string
	FriendshipRequesterID string
}

func NewPostgresRepository(db *gorm.DB) *PostgresRepository {
	return &PostgresRepository{db: db}
}

func (r *PostgresRepository) CreatePost(ctx context.Context, post domain.Post, imageURL string) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		postModel := feedPostModel{
			ID:           post.ID,
			AuthorUserID: post.Author.UserID,
			PostType:     post.Type,
			Caption:      post.Caption,
			CreatedAt:    post.CreatedAt,
		}
		if err := tx.Create(&postModel).Error; err != nil {
			return err
		}

		if imageURL == "" {
			return nil
		}

		return tx.Create(&feedMediaModel{
			ID:         identity.NewUUID(),
			FeedPostID: post.ID,
			MediaType:  domain.PostTypeImage,
			MediaURL:   imageURL,
			CreatedAt:  post.CreatedAt,
		}).Error
	})
}

func (r *PostgresRepository) ListPosts(ctx context.Context, actorUserID string, input domain.ListPostsInput) ([]domain.Post, error) {
	reactionCounts := r.db.WithContext(ctx).
		Table("feed_reactions").
		Select("feed_post_id, COUNT(*) AS reaction_count").
		Group("feed_post_id")

	commentCounts := r.db.WithContext(ctx).
		Table("feed_comments").
		Select("feed_post_id, COUNT(*) AS comment_count").
		Group("feed_post_id")

	query := r.db.WithContext(ctx).
		Table("feed_posts").
		Select(`
			feed_posts.id,
			feed_posts.author_user_id,
			users.username,
			user_profiles.display_name,
			user_profiles.avatar_url,
			user_profiles.city,
			feed_posts.post_type,
			feed_posts.caption,
			COALESCE(feed_media.media_url, '') AS image_url,
			COALESCE(reactions.reaction_count, 0) AS reaction_count,
			COALESCE(comments.comment_count, 0) AS comment_count,
			CASE WHEN my_reaction.user_id IS NULL THEN FALSE ELSE TRUE END AS reacted_by_me,
			feed_posts.created_at,
			COALESCE(friendships.status, '') AS friendship_status,
			COALESCE(friendships.requester_user_id, '') AS friendship_requester_id
		`).
		Joins("JOIN users ON users.id = feed_posts.author_user_id").
		Joins("JOIN user_profiles ON user_profiles.user_id = users.id").
		Joins("LEFT JOIN feed_media ON feed_media.feed_post_id = feed_posts.id").
		Joins("LEFT JOIN (?) reactions ON reactions.feed_post_id = feed_posts.id", reactionCounts).
		Joins("LEFT JOIN (?) comments ON comments.feed_post_id = feed_posts.id", commentCounts).
		Joins(`
			LEFT JOIN friendships ON (
				(friendships.requester_user_id = ? AND friendships.addressee_user_id = feed_posts.author_user_id)
				OR
				(friendships.addressee_user_id = ? AND friendships.requester_user_id = feed_posts.author_user_id)
			)
		`, actorUserID, actorUserID).
		Joins(`
			LEFT JOIN feed_reactions my_reaction
				ON my_reaction.feed_post_id = feed_posts.id
				AND my_reaction.user_id = ?
		`, actorUserID).
		Order("feed_posts.created_at DESC, feed_posts.id DESC").
		Limit(input.Limit)

	if input.AuthorUserID != "" {
		query = query.Where("feed_posts.author_user_id = ?", input.AuthorUserID)
	}
	if input.CursorCreatedAt != nil && input.CursorID != "" {
		query = query.Where(
			"(feed_posts.created_at < ?) OR (feed_posts.created_at = ? AND feed_posts.id < ?)",
			*input.CursorCreatedAt,
			*input.CursorCreatedAt,
			input.CursorID,
		)
	}

	rows := make([]feedPostRow, 0, input.Limit)
	if err := query.Scan(&rows).Error; err != nil {
		return nil, err
	}

	posts := make([]domain.Post, 0, len(rows))
	for _, current := range rows {
		posts = append(posts, mapPostRow(actorUserID, current))
	}

	return posts, nil
}

func (r *PostgresRepository) GetPost(ctx context.Context, actorUserID, postID string) (domain.Post, error) {
	var row feedPostRow
	reactionCounts := r.db.WithContext(ctx).
		Table("feed_reactions").
		Select("feed_post_id, COUNT(*) AS reaction_count").
		Group("feed_post_id")
	commentCounts := r.db.WithContext(ctx).
		Table("feed_comments").
		Select("feed_post_id, COUNT(*) AS comment_count").
		Group("feed_post_id")

	result := r.db.WithContext(ctx).
		Table("feed_posts").
		Select(`
			feed_posts.id,
			feed_posts.author_user_id,
			users.username,
			user_profiles.display_name,
			user_profiles.avatar_url,
			user_profiles.city,
			feed_posts.post_type,
			feed_posts.caption,
			COALESCE(feed_media.media_url, '') AS image_url,
			COALESCE(reactions.reaction_count, 0) AS reaction_count,
			COALESCE(comments.comment_count, 0) AS comment_count,
			CASE WHEN my_reaction.user_id IS NULL THEN FALSE ELSE TRUE END AS reacted_by_me,
			feed_posts.created_at,
			COALESCE(friendships.status, '') AS friendship_status,
			COALESCE(friendships.requester_user_id, '') AS friendship_requester_id
		`).
		Joins("JOIN users ON users.id = feed_posts.author_user_id").
		Joins("JOIN user_profiles ON user_profiles.user_id = users.id").
		Joins("LEFT JOIN feed_media ON feed_media.feed_post_id = feed_posts.id").
		Joins("LEFT JOIN (?) reactions ON reactions.feed_post_id = feed_posts.id", reactionCounts).
		Joins("LEFT JOIN (?) comments ON comments.feed_post_id = feed_posts.id", commentCounts).
		Joins(`
			LEFT JOIN friendships ON (
				(friendships.requester_user_id = ? AND friendships.addressee_user_id = feed_posts.author_user_id)
				OR
				(friendships.addressee_user_id = ? AND friendships.requester_user_id = feed_posts.author_user_id)
			)
		`, actorUserID, actorUserID).
		Joins(`
			LEFT JOIN feed_reactions my_reaction
				ON my_reaction.feed_post_id = feed_posts.id
				AND my_reaction.user_id = ?
		`, actorUserID).
		Where("feed_posts.id = ?", postID).
		Limit(1).
		Scan(&row)
	if result.Error != nil {
		return domain.Post{}, result.Error
	}
	if result.RowsAffected == 0 {
		return domain.Post{}, errors.New("post not found")
	}

	return mapPostRow(actorUserID, row), nil
}

func (r *PostgresRepository) ToggleReaction(ctx context.Context, postID, userID string, reactedAt time.Time) (domain.Post, error) {
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var existing feedReactionModel
		err := tx.Where("feed_post_id = ? AND user_id = ?", postID, userID).First(&existing).Error
		switch {
		case err == nil:
			return tx.Delete(&existing).Error
		case errors.Is(err, gorm.ErrRecordNotFound):
			return tx.Create(&feedReactionModel{
				FeedPostID: postID,
				UserID:     userID,
				CreatedAt:  reactedAt,
			}).Error
		default:
			return err
		}
	})
	if err != nil {
		return domain.Post{}, err
	}

	return r.GetPost(ctx, userID, postID)
}

func (r *PostgresRepository) CreateComment(ctx context.Context, comment domain.Comment) error {
	model := feedCommentModel{
		ID:              comment.ID,
		FeedPostID:      comment.PostID,
		ParentCommentID: nullableString(comment.ParentCommentID),
		AuthorUserID:    comment.Author.UserID,
		Body:            comment.Body,
		CreatedAt:       comment.CreatedAt,
	}

	return r.db.WithContext(ctx).Create(&model).Error
}

func (r *PostgresRepository) GetComment(ctx context.Context, commentID string) (domain.Comment, error) {
	type row struct {
		ID              string
		FeedPostID      string
		ParentCommentID *string
		AuthorUserID    string
		Username        string
		DisplayName     string
		AvatarURL       string
		City            string
		Body            string
		CreatedAt       time.Time
	}

	var current row
	result := r.db.WithContext(ctx).
		Table("feed_comments").
		Select(`
			feed_comments.id,
			feed_comments.feed_post_id,
			feed_comments.parent_comment_id,
			feed_comments.author_user_id,
			users.username,
			user_profiles.display_name,
			user_profiles.avatar_url,
			user_profiles.city,
			feed_comments.body,
			feed_comments.created_at
		`).
		Joins("JOIN users ON users.id = feed_comments.author_user_id").
		Joins("JOIN user_profiles ON user_profiles.user_id = users.id").
		Where("feed_comments.id = ?", commentID).
		Limit(1).
		Scan(&current)
	if result.Error != nil {
		return domain.Comment{}, result.Error
	}
	if result.RowsAffected == 0 {
		return domain.Comment{}, errors.New("comment not found")
	}

	return mapCommentRow(current.ID, current.FeedPostID, current.ParentCommentID, current.AuthorUserID, current.Username, current.DisplayName, current.AvatarURL, current.City, current.Body, current.CreatedAt), nil
}

func (r *PostgresRepository) ListComments(ctx context.Context, postID string, limit int) ([]domain.Comment, error) {
	type row struct {
		ID              string
		FeedPostID      string
		ParentCommentID *string
		AuthorUserID    string
		Username        string
		DisplayName     string
		AvatarURL       string
		City            string
		Body            string
		CreatedAt       time.Time
	}

	rows := make([]row, 0, limit)
	if err := r.db.WithContext(ctx).
		Table("feed_comments").
		Select(`
			feed_comments.id,
			feed_comments.feed_post_id,
			feed_comments.parent_comment_id,
			feed_comments.author_user_id,
			users.username,
			user_profiles.display_name,
			user_profiles.avatar_url,
			user_profiles.city,
			feed_comments.body,
			feed_comments.created_at
		`).
		Joins("JOIN users ON users.id = feed_comments.author_user_id").
		Joins("JOIN user_profiles ON user_profiles.user_id = users.id").
		Where("feed_comments.feed_post_id = ?", postID).
		Order(clause.OrderByColumn{Column: clause.Column{Name: "feed_comments.created_at"}, Desc: false}).
		Order(clause.OrderByColumn{Column: clause.Column{Name: "feed_comments.id"}, Desc: false}).
		Limit(limit).
		Scan(&rows).Error; err != nil {
		return nil, err
	}

	comments := make([]domain.Comment, 0, len(rows))
	for _, current := range rows {
		comments = append(
			comments,
			mapCommentRow(
				current.ID,
				current.FeedPostID,
				current.ParentCommentID,
				current.AuthorUserID,
				current.Username,
				current.DisplayName,
				current.AvatarURL,
				current.City,
				current.Body,
				current.CreatedAt,
			),
		)
	}

	return comments, nil
}

func mapPostRow(actorUserID string, current feedPostRow) domain.Post {
	return domain.Post{
		ID: current.ID,
		Author: domain.Author{
			UserID:           current.AuthorUserID,
			Username:         current.Username,
			DisplayName:      current.DisplayName,
			AvatarURL:        current.AvatarURL,
			City:             current.City,
			ConnectionStatus: connectionStatusForAuthor(actorUserID, current.AuthorUserID, current.FriendshipStatus, current.FriendshipRequesterID),
		},
		Type:          current.PostType,
		Caption:       current.Caption,
		ImageURL:      current.ImageURL,
		ReactionCount: current.ReactionCount,
		CommentCount:  current.CommentCount,
		ReactedByMe:   current.ReactedByMe,
		CreatedAt:     current.CreatedAt,
	}
}

func mapCommentRow(id, postID string, parentCommentID *string, authorUserID, username, displayName, avatarURL, city, body string, createdAt time.Time) domain.Comment {
	comment := domain.Comment{
		ID:     id,
		PostID: postID,
		Author: domain.Author{
			UserID:      authorUserID,
			Username:    username,
			DisplayName: displayName,
			AvatarURL:   avatarURL,
			City:        city,
		},
		Body:      body,
		CreatedAt: createdAt,
	}
	if parentCommentID != nil {
		comment.ParentCommentID = *parentCommentID
	}
	return comment
}

func connectionStatusForAuthor(actorUserID, authorUserID, friendshipStatus, friendshipRequesterID string) string {
	if actorUserID == "" || actorUserID == authorUserID {
		return ""
	}

	switch friendshipStatus {
	case "accepted":
		return "friends"
	case "pending":
		if friendshipRequesterID == actorUserID {
			return "requested"
		}
		return "incoming_request"
	default:
		return "add"
	}
}

func nullableString(value string) *string {
	if value == "" {
		return nil
	}
	return &value
}
