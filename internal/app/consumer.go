package app

import "go.uber.org/zap"

func RunConsumer(app *App) error {
	app.Logger.Info("consumer booted", zap.String("rabbitmq_url", app.Config.RabbitMQURL))
	return nil
}
