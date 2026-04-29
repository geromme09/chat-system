package observability

import (
	"context"
	"fmt"

	"github.com/geromme09/chat-system/internal/platform/config"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	tracesdk "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.37.0"
	"go.uber.org/zap"
)

func Setup(ctx context.Context, cfg config.Config, logger *zap.Logger) (func(context.Context) error, error) {
	if !cfg.ObservabilityEnabled || !cfg.TracingEnabled {
		return func(context.Context) error { return nil }, nil
	}

	options := []otlptracehttp.Option{
		otlptracehttp.WithEndpoint(cfg.TracingOTLPEndpoint),
	}
	if cfg.TracingOTLPInsecure {
		options = append(options, otlptracehttp.WithInsecure())
	}

	exporter, err := otlptracehttp.New(ctx, options...)
	if err != nil {
		return nil, fmt.Errorf("create otlp trace exporter: %w", err)
	}

	res, err := resource.New(
		ctx,
		resource.WithAttributes(
			semconv.ServiceNameKey.String(cfg.ObservabilitySvcName),
			semconv.DeploymentEnvironmentNameKey.String(cfg.Env),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("build telemetry resource: %w", err)
	}

	tracerProvider := tracesdk.NewTracerProvider(
		tracesdk.WithBatcher(exporter),
		tracesdk.WithSampler(tracesdk.ParentBased(tracesdk.TraceIDRatioBased(cfg.TracingSampleRatio))),
		tracesdk.WithResource(res),
	)

	otel.SetTracerProvider(tracerProvider)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	logger.Info("tracing enabled",
		zap.String("otlp_endpoint", cfg.TracingOTLPEndpoint),
		zap.Float64("sample_ratio", cfg.TracingSampleRatio),
	)

	return tracerProvider.Shutdown, nil
}
