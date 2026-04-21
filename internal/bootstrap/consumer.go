package bootstrap

func RunConsumer(app *App) error {
	app.Logger.Info("consumer booted", "rabbitmq_url", app.Config.RabbitMQURL)
	return nil
}
