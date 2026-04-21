package infra

import (
	"context"
	"strings"

	"github.com/geromme09/chat-system/internal/modules/sport/domain"
	"gorm.io/gorm"
)

type PostgresRepository struct {
	db *gorm.DB
}

func NewPostgresRepository(db *gorm.DB) *PostgresRepository {
	return &PostgresRepository{db: db}
}

func (r *PostgresRepository) ListSports(ctx context.Context, query string, offset, limit int) ([]domain.Sport, error) {
	db := r.db.WithContext(ctx).
		Model(&sportModel{}).
		Where("is_active = ?", true)

	if trimmed := strings.TrimSpace(query); trimmed != "" {
		like := "%" + trimmed + "%"
		db = db.Where("name ILIKE ? OR slug ILIKE ?", like, like)
	}

	var rows []sportModel
	if err := db.Order("sort_order ASC").Order("name ASC").Offset(offset).Limit(limit).Find(&rows).Error; err != nil {
		return nil, err
	}

	sports := make([]domain.Sport, 0, len(rows))
	for _, row := range rows {
		sports = append(sports, domain.Sport{
			ID:        row.ID,
			Name:      row.Name,
			Slug:      row.Slug,
			IconURL:   row.IconURL,
			IsActive:  row.IsActive,
			SortOrder: row.SortOrder,
		})
	}

	return sports, nil
}
