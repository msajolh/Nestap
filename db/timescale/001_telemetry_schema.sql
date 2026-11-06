-- =============================================================================
-- Nestap telemetry schema · TimescaleDB 2.x on PostgreSQL 16
--
-- A separate cluster from the core database: write-heavy, append-only, with
-- compression and retention policies. Written only by the history service
-- (from Kafka), read by the history API.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE SCHEMA IF NOT EXISTS telemetry;

-- -----------------------------------------------------------------------------
-- DP history: one row per DP change (or sample, per the DP's report_policy.history)
-- -----------------------------------------------------------------------------
CREATE TABLE telemetry.dp_history (
  time       timestamptz NOT NULL,              -- device ts if sane, else broker ts
  device_id  text        NOT NULL,
  dp_code    text        NOT NULL,
  v_num      double precision,                  -- value/enum index already scaled
  v_bool     boolean,
  v_text     text,                              -- enum/string
  v_json     jsonb,                             -- json/raw(base64)/bitmap
  source     text        NOT NULL DEFAULT 'device'
               CHECK (source IN ('device', 'local', 'lan', 'cloud', 'app', 'automation', 'voice', 'schedule'))
);
SELECT create_hypertable('telemetry.dp_history', by_range('time', INTERVAL '1 day'));
CREATE INDEX dp_history_device_idx ON telemetry.dp_history (device_id, dp_code, time DESC);

ALTER TABLE telemetry.dp_history SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'device_id, dp_code',
  timescaledb.compress_orderby   = 'time DESC'
);
SELECT add_compression_policy('telemetry.dp_history', INTERVAL '7 days');
SELECT add_retention_policy('telemetry.dp_history', INTERVAL '180 days');

-- -----------------------------------------------------------------------------
-- Energy: normalised samples from metering DPs (cur_power, cur_voltage,
-- cur_current, add_ele) so energy queries never parse DP codes.
-- -----------------------------------------------------------------------------
CREATE TABLE telemetry.energy_samples (
  time             timestamptz NOT NULL,
  device_id        text        NOT NULL,
  home_id          uuid        NOT NULL,        -- denormalised for per-home dashboards
  power_w          real,
  voltage_v        real,
  current_ma       real,
  energy_wh_delta  real                         -- energy since previous sample (from add_ele)
);
SELECT create_hypertable('telemetry.energy_samples', by_range('time', INTERVAL '1 day'));
CREATE INDEX energy_samples_device_idx ON telemetry.energy_samples (device_id, time DESC);

ALTER TABLE telemetry.energy_samples SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'device_id',
  timescaledb.compress_orderby   = 'time DESC'
);
SELECT add_compression_policy('telemetry.energy_samples', INTERVAL '3 days');
SELECT add_retention_policy('telemetry.energy_samples', INTERVAL '90 days');

-- Hourly rollup, kept 3 years. Daily/monthly views are computed from this at
-- query time in the home's timezone (a UTC daily bucket would be wrong for
-- most users).
CREATE MATERIALIZED VIEW telemetry.energy_hourly
WITH (timescaledb.continuous) AS
SELECT time_bucket(INTERVAL '1 hour', time) AS bucket,
       device_id,
       home_id,
       sum(energy_wh_delta)                 AS energy_wh,
       avg(power_w)                         AS avg_power_w,
       max(power_w)                         AS max_power_w,
       avg(voltage_v)                       AS avg_voltage_v
FROM telemetry.energy_samples
GROUP BY bucket, device_id, home_id
WITH NO DATA;

SELECT add_continuous_aggregate_policy('telemetry.energy_hourly',
  start_offset      => INTERVAL '6 hours',
  end_offset        => INTERVAL '1 hour',
  schedule_interval => INTERVAL '30 minutes');
SELECT add_retention_policy('telemetry.energy_hourly', INTERVAL '3 years');

-- -----------------------------------------------------------------------------
-- Device events (alarms, faults, button presses)
-- -----------------------------------------------------------------------------
CREATE TABLE telemetry.device_events (
  time       timestamptz NOT NULL,
  device_id  text        NOT NULL,
  code       text        NOT NULL,
  payload    jsonb       NOT NULL DEFAULT '{}'
);
SELECT create_hypertable('telemetry.device_events', by_range('time', INTERVAL '7 days'));
CREATE INDEX device_events_device_idx ON telemetry.device_events (device_id, time DESC);
SELECT add_retention_policy('telemetry.device_events', INTERVAL '365 days');

-- -----------------------------------------------------------------------------
-- Connectivity log (online/offline transitions after the 30 s grace period)
-- -----------------------------------------------------------------------------
CREATE TABLE telemetry.connectivity (
  time         timestamptz NOT NULL,
  device_id    text        NOT NULL,
  online       boolean     NOT NULL,
  reason       text,                            -- normal, keepalive_timeout, kicked, auth_failed ...
  ip           inet,
  broker_node  text,
  fw_main      text,
  rssi         smallint
);
SELECT create_hypertable('telemetry.connectivity', by_range('time', INTERVAL '7 days'));
CREATE INDEX connectivity_device_idx ON telemetry.connectivity (device_id, time DESC);
SELECT add_retention_policy('telemetry.connectivity', INTERVAL '90 days');

-- -----------------------------------------------------------------------------
-- Command log (every cloud command and its outcome)
-- -----------------------------------------------------------------------------
CREATE TABLE telemetry.command_log (
  time         timestamptz NOT NULL,            -- when the command was accepted
  command_id   text        NOT NULL,
  device_id    text        NOT NULL,
  actor_type   text        NOT NULL CHECK (actor_type IN ('user', 'automation', 'schedule', 'voice', 'partner', 'admin')),
  actor_id     text,                            -- user id / rule id / client id
  dps          jsonb       NOT NULL,
  status       text        NOT NULL CHECK (status IN ('sent', 'acked', 'rejected', 'timeout', 'offline')),
  ack_code     smallint,
  latency_ms   integer
);
SELECT create_hypertable('telemetry.command_log', by_range('time', INTERVAL '1 day'));
CREATE INDEX command_log_device_idx ON telemetry.command_log (device_id, time DESC);
CREATE INDEX command_log_id_idx     ON telemetry.command_log (command_id, time DESC);
SELECT add_retention_policy('telemetry.command_log', INTERVAL '30 days');

-- -----------------------------------------------------------------------------
-- Automation run log
-- -----------------------------------------------------------------------------
CREATE TABLE telemetry.automation_runs (
  time         timestamptz NOT NULL,
  run_id       text        NOT NULL,
  rule_id      uuid        NOT NULL,
  home_id      uuid        NOT NULL,
  trigger      jsonb       NOT NULL,            -- what fired it
  status       text        NOT NULL CHECK (status IN ('running', 'succeeded', 'partial', 'failed', 'skipped')),
  duration_ms  integer,
  details      jsonb       NOT NULL DEFAULT '{}'  -- per-action outcome
);
SELECT create_hypertable('telemetry.automation_runs', by_range('time', INTERVAL '7 days'));
CREATE INDEX automation_runs_rule_idx ON telemetry.automation_runs (rule_id, time DESC);
CREATE INDEX automation_runs_home_idx ON telemetry.automation_runs (home_id, time DESC);
SELECT add_retention_policy('telemetry.automation_runs', INTERVAL '30 days');

-- -----------------------------------------------------------------------------
-- Audit log (security-relevant actions by users, admins and integrations)
-- -----------------------------------------------------------------------------
CREATE TABLE telemetry.audit_log (
  time         timestamptz NOT NULL,
  actor_type   text        NOT NULL,            -- user, admin, device, system, integration
  actor_id     text,
  action       text        NOT NULL,            -- 'device.unbind', 'home.member.remove', 'session.revoke' ...
  target_type  text,
  target_id    text,
  home_id      uuid,
  ip           inet,
  metadata     jsonb       NOT NULL DEFAULT '{}'
);
SELECT create_hypertable('telemetry.audit_log', by_range('time', INTERVAL '30 days'));
CREATE INDEX audit_log_actor_idx  ON telemetry.audit_log (actor_id, time DESC);
CREATE INDEX audit_log_target_idx ON telemetry.audit_log (target_type, target_id, time DESC);
SELECT add_retention_policy('telemetry.audit_log', INTERVAL '730 days');
