package observability

import (
	"database/sql"
	"sync"

	"github.com/prometheus/client_golang/prometheus"
)

var (
	dbMetricsOnce sync.Once
	dbCollector   = &dbStatsCollector{}
)

type dbStatsCollector struct {
	mu sync.RWMutex
	db *sql.DB
}

func RegisterDBStats(db *sql.DB) {
	if db == nil {
		return
	}

	dbMetricsOnce.Do(func() {
		prometheus.MustRegister(dbCollector)
	})

	dbCollector.mu.Lock()
	dbCollector.db = db
	dbCollector.mu.Unlock()
}

func (c *dbStatsCollector) Describe(ch chan<- *prometheus.Desc) {
	descs := []*prometheus.Desc{
		dbConnectionsOpenDesc,
		dbConnectionsInUseDesc,
		dbConnectionsIdleDesc,
		dbConnectionsMaxOpenDesc,
		dbWaitCountDesc,
		dbWaitDurationSecondsDesc,
		dbMaxIdleClosedTotalDesc,
		dbMaxIdleTimeClosedTotalDesc,
		dbMaxLifetimeClosedTotalDesc,
	}
	for _, desc := range descs {
		ch <- desc
	}
}

func (c *dbStatsCollector) Collect(ch chan<- prometheus.Metric) {
	c.mu.RLock()
	db := c.db
	c.mu.RUnlock()
	if db == nil {
		return
	}

	stats := db.Stats()
	ch <- prometheus.MustNewConstMetric(dbConnectionsOpenDesc, prometheus.GaugeValue, float64(stats.OpenConnections))
	ch <- prometheus.MustNewConstMetric(dbConnectionsInUseDesc, prometheus.GaugeValue, float64(stats.InUse))
	ch <- prometheus.MustNewConstMetric(dbConnectionsIdleDesc, prometheus.GaugeValue, float64(stats.Idle))
	ch <- prometheus.MustNewConstMetric(dbConnectionsMaxOpenDesc, prometheus.GaugeValue, float64(stats.MaxOpenConnections))
	ch <- prometheus.MustNewConstMetric(dbWaitCountDesc, prometheus.CounterValue, float64(stats.WaitCount))
	ch <- prometheus.MustNewConstMetric(dbWaitDurationSecondsDesc, prometheus.CounterValue, stats.WaitDuration.Seconds())
	ch <- prometheus.MustNewConstMetric(dbMaxIdleClosedTotalDesc, prometheus.CounterValue, float64(stats.MaxIdleClosed))
	ch <- prometheus.MustNewConstMetric(dbMaxIdleTimeClosedTotalDesc, prometheus.CounterValue, float64(stats.MaxIdleTimeClosed))
	ch <- prometheus.MustNewConstMetric(dbMaxLifetimeClosedTotalDesc, prometheus.CounterValue, float64(stats.MaxLifetimeClosed))
}

var (
	dbConnectionsOpenDesc = prometheus.NewDesc(
		"chat_system_db_connections_open",
		"Current number of open database connections.",
		nil,
		nil,
	)
	dbConnectionsInUseDesc = prometheus.NewDesc(
		"chat_system_db_connections_in_use",
		"Current number of database connections in use.",
		nil,
		nil,
	)
	dbConnectionsIdleDesc = prometheus.NewDesc(
		"chat_system_db_connections_idle",
		"Current number of idle database connections.",
		nil,
		nil,
	)
	dbConnectionsMaxOpenDesc = prometheus.NewDesc(
		"chat_system_db_connections_max_open",
		"Configured maximum number of open database connections.",
		nil,
		nil,
	)
	dbWaitCountDesc = prometheus.NewDesc(
		"chat_system_db_wait_count_total",
		"Total number of times the database connection pool had to wait for a free connection.",
		nil,
		nil,
	)
	dbWaitDurationSecondsDesc = prometheus.NewDesc(
		"chat_system_db_wait_duration_seconds_total",
		"Total time blocked waiting for a free database connection.",
		nil,
		nil,
	)
	dbMaxIdleClosedTotalDesc = prometheus.NewDesc(
		"chat_system_db_max_idle_closed_total",
		"Total database connections closed due to SetMaxIdleConns.",
		nil,
		nil,
	)
	dbMaxIdleTimeClosedTotalDesc = prometheus.NewDesc(
		"chat_system_db_max_idle_time_closed_total",
		"Total database connections closed due to SetConnMaxIdleTime.",
		nil,
		nil,
	)
	dbMaxLifetimeClosedTotalDesc = prometheus.NewDesc(
		"chat_system_db_max_lifetime_closed_total",
		"Total database connections closed due to SetConnMaxLifetime.",
		nil,
		nil,
	)
)
