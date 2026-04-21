package infra

type sportModel struct {
	ID        string `gorm:"primaryKey"`
	Name      string
	Slug      string
	IconURL   string
	IsActive  bool
	SortOrder int
}

func (sportModel) TableName() string {
	return "sports"
}
