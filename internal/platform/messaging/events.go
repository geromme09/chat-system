package messaging

import "context"

type Event struct {
	Name        string
	Version     int
	Aggregate   string
	AggregateID string
	Payload     map[string]any
}

type Publisher interface {
	Publish(ctx context.Context, event Event) error
}

type NoopPublisher struct{}

func (NoopPublisher) Publish(context.Context, Event) error {
	return nil
}
