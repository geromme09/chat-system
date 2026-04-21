package domain

import "context"

type Sport struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	Slug      string `json:"slug"`
	IconURL   string `json:"icon_url,omitempty"`
	IsActive  bool   `json:"is_active"`
	SortOrder int    `json:"sort_order"`
}

type Repository interface {
	ListSports(ctx context.Context, query string, offset, limit int) ([]Sport, error)
}
