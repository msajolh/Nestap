# 04 · Backend Services

## 1. Service map

| # | Service | Kind | Owns (DB) | Public API | Consumes | Produces |
|---|---------|------|-----------|------------|----------|----------|
| 1 | **identity** | API | `identity.*` | `/v1/auth`, `/v1/users`, `/oauth2` | – | `user.events` |
| 2 | **home** | API | `home.*` | `/v1/homes` | `user.events` | `home.events` |
| 3 | **catalog** | API | `catalog.*` | `/v1/products`, `/v1/categories`, vendor console | – | `catalog.events` |
| 4 | **device-registry** | API + worker | `device.*` (except shadows) | `/v1/pairing`, `/v1/devices`, `/v1/groups`, activation API | `device.uplink` (topo), `home.events`, `user.events` | `device.registry` |
| 5 | **device-connect** | EMQX hook | – (reads `device.devices`) | internal only: `/mqtt/authn`, `/mqtt/authz` | `device.registry` (revocations) | – |
| 6 | **shadow** | worker + gRPC | `device.shadows` | via device-registry `GET /v1/devices/{id}/state` | `device.uplink`, `device.lifecycle` | `device.state.changed`, `device.presence.changed`, `device.events` |
| 7 | **command** | API + worker | – (Redis only) | `/v1/devices/{id}/commands`, `/v1/groups/{id}/commands` | `device.uplink` (acks) | `command.results` |
| 8 | **automation** | API + engine | `automation.rules`, `rule_triggers` | `/v1/homes/{id}/rules` | `device.state.changed`, `device.events`, `device.presence.changed`, `schedule.fired`, `home.events`, `device.registry` | `automation.runs`, `notification.requests` |
| 9 | **scheduler** | worker + API | `automation.schedules` | `/v1/devices/{id}/timers` | `device.registry`, `home.events` | `schedule.fired` |
| 10 | **history** | API + writer | TimescaleDB `telemetry.*` | `/v1/devices/{id}/history`, `/v1/homes/{id}/energy`, logs | everything worth logging | – |
| 11 | **realtime** | WebSocket gateway | – (Redis pub/sub) | `wss://rt.{region}…/v1/stream` | `device.state.changed`, `device.presence.changed`, `command.results`, `device.registry`, `ota.progress`, `home.events` | – |
| 12 | **notification** | worker + API | `notify.*` | `/v1/messages`, `/v1/push-tokens`, `/v1/notification-settings` | `notification.requests`, `device.events`, `device.presence.changed` | – |
| 13 | **ota** | API + worker | `ota.*` | `/v1/devices/{id}/firmware`, vendor console | `device.uplink` (progress, hello) | `ota.progress`, `notification.requests` |
| 14 | **integration** | API + worker | `integration.*` | `/v1/integrations`, Alexa/Google fulfilment endpoints, Open API | `device.state.changed`, `device.presence.changed`, `device.registry` | – |
| 15 | **connector** | API + worker | `connector.*` | `/v1/connectors/tuya/session`, `/v1/devices/import` | Tuya message service, `device.registry`, `home.events` | `device.uplink`, `device.lifecycle` (for `tuya_cloud` devices) |

Not services but part of the backend:

- **API gateway (Envoy):** TLS termination, JWT verification (JWKS from identity), per-user/IP rate limits, routing by path prefix, request IDs and trace start.
- **Outbox relay:** a small worker that tails `infra.outbox` and publishes to Kafka (one instance with leader election).
- **Admin APIs:** each service exposes `/admin/v1/...` routes, enabled only for tokens with the `admin` scope from the ops SSO. There's no separate admin service.

## 2. Conventions

### 2.1 Public REST

| Topic | Convention |
|-------|------------|
| Base URL | `https://api.{region}.nestap.io/v1/...` |
| Auth | `Authorization: Bearer <JWT>` (ES256, 15 min). Claims: `sub`, `region`, `app_id`, `scope`, `sid` |
| IDs | UUIDv7 strings; devices `nd…`, products `p…` |
| Time | RFC 3339 UTC in JSON; history/energy queries accept `tz` |
| Pagination | Cursor: `?limit=50&cursor=…` → `{ "items": [...], "next_cursor": "…" }` |
| Idempotency | `Idempotency-Key` header on every POST that creates or commands; stored 24 h in Redis |
| Errors | `{"error":{"code":"DEVICE_OFFLINE","message":"…","request_id":"…","details":{}}}` with a matching HTTP status |
| i18n | `Accept-Language`; product/DP names returned localised from the catalog |
| Versioning | URL major version; additive changes only within `v1` |

Standard error codes: `UNAUTHENTICATED` 401, `FORBIDDEN` 403, `NOT_FOUND` 404 (also used when the caller has no access), `CONFLICT` 409, `DEVICE_OFFLINE` 409, `VALIDATION_FAILED` 422, `DP_READ_ONLY` 422, `DP_OUT_OF_RANGE` 422, `RATE_LIMITED` 429, `DEVICE_TIMEOUT` 504.

### 2.2 Internal

- **gRPC** for synchronous calls, always with deadlines (default 2 s), only where a request needs an answer now: `command → registry.GetDeviceMeta`, `automation → command.Execute`, `realtime → home.CheckMembership`. Most of these are cache-backed.
- **Kafka** for everything else. Services never read each other's tables.

### 2.3 Event envelope (Kafka)

JSON, CloudEvents 1.0 structured mode:

```json
{
  "specversion": "1.0",
  "id": "01JC8F3WZ6Q9K4V2",
  "type": "device.state.changed",
  "source": "shadow",
  "subject": "nd3f9k2m7q1x8c4v6b0n2a",
  "time": "2026-11-07T10:12:03.120Z",
  "datacontenttype": "application/json",
  "nestaphomeid": "0193a1e2-...",
  "nestapcause": "cmd_01JC8F3V..|rule_0193..",
  "traceparent": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  "data": {
    "version": 122,
    "changed": { "switch_1": false },
    "state": { "switch_1": false, "switch_2": true, "cur_power": 0.0 },
    "source": "cloud",
    "device_ts": 1762510323090
  }
}
```

- Partition key = `subject` (device ID) for device topics, `home_id` for home topics.
- `nestapcause` is a chain of causing command/rule IDs. The automation engine refuses to run a rule whose ID is already in the chain, or when the chain is longer than 5 (loop guard).
- Schemas are kept in `api/events/*.json` (JSON Schema) and checked in CI. A breaking change gets a new `type` (`device.state.changed.v2`).

## 3. Kafka topic catalog

| Topic | Key | Producer | Consumers | Partitions | Retention |
|-------|-----|----------|-----------|-----------:|-----------|
| `device.uplink` | device_id | EMQX rule, connector | shadow, command, ota, device-registry, history | 48 | 3 d |
| `device.lifecycle` | device_id | EMQX rule, connector | shadow | 24 | 3 d |
| `device.state.changed` | device_id | shadow | automation, realtime, history, integration, notification | 48 | 7 d |
| `device.presence.changed` | device_id | shadow | realtime, history, automation, notification, integration, ota | 24 | 7 d |
| `device.events` | device_id | shadow | automation, notification, history | 24 | 7 d |
| `device.registry` | device_id | device-registry (outbox) | device-connect, realtime, automation, scheduler, integration, ota, shadow | 12 | 30 d |
| `command.results` | device_id | command | history, realtime, automation | 24 | 3 d |
| `schedule.fired` | home_id | scheduler | automation, command (device timers) | 12 | 3 d |
| `automation.runs` | home_id | automation | history, realtime | 12 | 3 d |
| `notification.requests` | user_id | any | notification | 12 | 3 d |
| `ota.progress` | device_id | ota | realtime, history | 12 | 7 d |
| `home.events` | home_id | home (outbox) | device-registry, automation, scheduler, realtime, command, notification | 12 | 30 d |
| `user.events` | user_id | identity (outbox) | all services (deletion, profile) | 6 | 30 d |
| `catalog.events` | product_id | catalog (outbox) | all services (thing-model cache) | 3 | compacted |
| `audit` | actor_id | all | history | 6 | 7 d |

Producer settings: `acks=all`, idempotent producer, `lz4` compression. Consumers commit offsets after processing. Every handler is idempotent.

---

## 4. identity

**Purpose:** accounts, login, tokens, OAuth2 for third parties.

- Sign-up/sign-in: email + password (argon2id), phone/email OTP (6 digits, 5 min, 5 attempts), Google/Apple ID token exchange.
- Tokens: JWT access token (15 min, ES256, key rotation every 30 days, JWKS at `/.well-known/jwks.json`) + opaque refresh token (30 days, rotated on each use, family revoked if an old one is reused).
- OAuth2 authorization server (authorization code + PKCE) for Alexa/Google account linking and partners, with scopes `devices:read`, `devices:control`, `homes:read`, `scenes:run`.
- Account deletion: 7-day grace (`pending_deletion`), then emits `user.deleted`.
- Global account directory (Phase 3): a small global table `login_id_hash → region` queried by the app before login.

| Endpoint | Description |
|----------|-------------|
| `POST /v1/auth/otp` | Send OTP to email/phone |
| `POST /v1/auth/token` | Grant types: `password`, `otp`, `refresh_token`, `google`, `apple` |
| `POST /v1/auth/logout` | Revoke current session |
| `GET/PATCH /v1/users/me` | Profile, locale, timezone |
| `GET /v1/users/me/sessions`, `DELETE …/{id}` | Manage logged-in phones |
| `DELETE /v1/users/me` | Start account deletion |
| `GET /oauth2/authorize`, `POST /oauth2/token` | Third-party OAuth2 |

## 5. home

**Purpose:** homes, rooms, membership, invitations.

- A user gets a default home at sign-up. The owner role is transferable (exactly one owner, enforced by a partial unique index).
- Invitations: code or deep link, 72 h expiry, role `admin` or `member`, optional room restriction.
- Emits `home.member.added|removed|role_changed`, `home.deleted`, `home.updated` (timezone/location changes reschedule sun-based jobs).

| Endpoint | Description |
|----------|-------------|
| `GET/POST /v1/homes`, `GET/PATCH/DELETE /v1/homes/{id}` | Homes |
| `GET/POST /v1/homes/{id}/rooms`, `PATCH/DELETE …/rooms/{roomId}`, `PUT …/rooms/order` | Rooms |
| `GET /v1/homes/{id}/members`, `PATCH/DELETE …/members/{userId}` | Members |
| `POST /v1/homes/{id}/invitations`, `POST /v1/invitations/{code}/accept` | Invitations |
| `POST /v1/homes/{id}/transfer` | Transfer ownership |

## 6. catalog

**Purpose:** vendors, white-label apps, categories, products and their thing models. This is the **global** service, replicated read-only to each region.

- Vendor console API (separate audience, `vendor:*` scopes): create a product, edit its DPs, upload a panel config, request a license batch, upload firmware (forwarded to ota).
- Validation: DP ids 1–255 unique, codes `^[a-z][a-z0-9_]{1,31}$`, standard DPs required per category, `spec` valid for its `type`.
- Releasing a product freezes its DP ids. Changes after release are additive and bump `thing_model_version`.
- Every service keeps an in-memory thing-model cache refreshed from `catalog.events`.

| Endpoint | Description |
|----------|-------------|
| `GET /v1/products/{pid}` | Product + thing model + panel (app renders the device screen from this) |
| `GET /v1/categories` | Category tree for "Add device" screens |
| `POST/PATCH /vendor/v1/products…`, `PUT …/datapoints` | Vendor console |

## 7. device-registry and device-connect

### 7.1 device-registry

**Purpose:** the life of a device from factory to unbinding.

- **Licenses:** generate batches (`uuid` + random 128-bit `authKey`), export the encrypted CSV for the factory, revoke a batch.
- **Pairing:** issue pairing tokens (`POST /v1/pairing/tokens` → `{token:"AP7Kq2Xz9w", expires_in:600}`). The token's first two characters are the region code.
- **Activation API** (`POST https://a.{region}.nestap.io/v1/device/activate`, called by devices): checks the license, signature and token, creates the `devices` row plus an empty shadow, binds it to the home/room, and returns encrypted credentials (see [05-key-flows.md §1](05-key-flows.md#1-device-pairing-and-activation)).
- **Topology:** handles gateway `topo/add|remove` from `device.uplink`.
- **Management:** rename, move room, share, unbind (`rpc unbind` to the device if online, then the row goes `unbound`, secrets are nulled, `dev:revoked` is published and the broker session is kicked), groups.
- **Reacts to:** `home.deleted` → unbind all its devices; `user.deleted` → drop shares, and for homes they own, the home cascade.

| Endpoint | Description |
|----------|-------------|
| `POST /v1/pairing/tokens`, `GET /v1/pairing/tokens/{token}/devices` | Pairing session + polling for newly activated devices |
| `GET /v1/homes/{id}/devices` | Device list with shadow + presence (merged from Redis) |
| `GET/PATCH/DELETE /v1/devices/{id}` | Details (includes `localKey` for control-capable users), rename/move, unbind |
| `GET /v1/devices/{id}/state` | Current shadow (served from shadow via gRPC) |
| `POST/DELETE /v1/devices/{id}/shares` | Share with a user by email/phone |
| `GET /v1/gateways/{id}/sub-devices`, `POST …/permit-join` | Gateway management (permit-join opens `topo/add` for 120 s) |
| `GET/POST /v1/homes/{id}/groups`, `PATCH/DELETE /v1/groups/{id}` | Groups |
| `POST /admin/v1/license-batches`, `POST …/{id}/revoke` | Factory licensing |

### 7.2 device-connect

**Purpose:** EMQX authentication and authorization hooks. Latency-critical (every CONNECT, every first publish per topic).

- `POST /mqtt/authn` `{clientid, username, password, peerhost}` → `allow`/`deny` + `is_superuser`. Checks the HMAC as described in [02-mqtt-protocol.md §3](02-mqtt-protocol.md#3-device-identity-and-authentication).
- `POST /mqtt/authz` `{clientid, topic, action}` → pure string check against the `nt/v1/{clientid}/up|down/#` rules. No database.
- Secret lookup: in-process LRU → Redis `dev:auth:{id}` → PostgreSQL. Decrypts with a Vault/KMS data key that is cached in memory.
- Target: p99 < 5 ms. Stateless, 3+ replicas. Reconnect storms after a broker restart are absorbed by the LRU + Redis.

## 8. shadow and command

### 8.1 shadow

**Purpose:** turn raw uplink into trusted device state, and own presence.

Pipeline per `device.uplink` message (single consumer group, partitioned by device, so there are no concurrent updates per device):

1. Parse the envelope and resolve `dev:meta` (product, thing-model version, home, gateway). For `sub/{subId}`, check `subId.gateway_id == device_id`.
2. `prop/report`: map DP ids → codes (connector messages already carry `codes`; see [06-device-compatibility.md §3.4](06-device-compatibility.md#34-state-presence-and-commands)), validate type/range (out-of-range values are dropped and counted), apply `scale`, enforce `min_interval_s`.
3. Atomic Redis Lua update: reject if `seq` ≤ stored `seq` within the same boot, merge `reported`, bump `version`, return the changed keys.
4. If anything changed, emit `device.state.changed` with `changed` + full `state`, and mark the device dirty for the PostgreSQL write-behind.
5. `event/{code}` → validate against the thing-model event list → `device.events`.
6. `shadow/get` → reply on `down/shadow/sync` with any `desired` entries newer than the device's version. Clear them once the device reports the same values.
7. Presence from `device.lifecycle` with the 30 s offline grace → `device.presence.changed`.

gRPC: `GetShadow(device_ids[])` (batched for home device lists), `SetDesired(device_id, dps)` (for `offline_queue` DPs).

### 8.2 command

**Purpose:** send commands to devices safely and track the outcome.

`POST /v1/devices/{id}/commands`

```json
{ "dps": { "switch_1": true, "countdown_1": 600 } }
```

1. Authorise (permission cache → registry/home gRPC on a miss). Read-only viewers get `403`.
2. Validate against the thing model: code exists, `mode` ≠ `ro`, type and range OK. Convert to wire `{dp_id: scaled_int}`.
3. Presence check `dev:online:{id}` (for a sub-device: the gateway is online and the sub-device isn't reported offline). Offline → `409 DEVICE_OFFLINE`, except DPs with `offline_queue: true`, which go to `shadow.SetDesired` → `202 {"queued": true}`.
4. Route by `devices.transport`: `nestap_mqtt`/`gateway_*` → publish `down/prop/set` (QoS 1, expiry 30 s); `tuya_cloud` → `connector.SendCommand` (Tuya OpenAPI; HTTP success = ack). Store `cmd:{id}` (60 s).
5. Respond `202 {"command_id":"c_01J…"}`. The app shows the optimistic state and confirms it from the realtime `state.changed`.
6. On `prop/set/ack` → `command.results {status: acked|rejected, ack_code, latency_ms}`. No ack within 10 s → `timeout`.

Optional `?wait=true` holds the HTTP response until the ack arrives (max 5 s). It's used by voice integrations, which need a synchronous answer.

**Group commands** (`POST /v1/groups/{id}/commands`): for a Zigbee/BLE-mesh group with a `gateway_id`, one `rpc/req {method:"group_set"}` goes to the gateway (one radio frame, lights switch in sync). Otherwise it fans out per device, with a concurrency cap of 20.

**Internal gRPC** `Execute(actor, device_id, dps)` is used by automation, scheduler and integration with the same validation path; the actor is recorded in the command log.

## 9. Automation

**Purpose:** scenes and automations. The rule CRUD API and the evaluation engine live in one service; the engine is a separate deployment in Phase 2.

### 9.1 Rule document

```json
{
  "kind": "automation",
  "name": "Hallway light at night",
  "match": "all",
  "conditions": [
    { "type": "device_dp", "device_id": "nd9a…", "dp": "pir_state", "op": "==", "value": "pir" },
    { "type": "device_dp", "device_id": "nd4c…", "dp": "bright_state", "op": "==", "value": "low" }
  ],
  "preconditions": [
    { "type": "time_window", "from": "18:00", "to": "06:00", "days": [0,1,2,3,4,5,6] }
  ],
  "actions": [
    { "type": "device", "device_id": "nd3f…", "dps": { "switch_1": true } },
    { "type": "delay", "seconds": 300 },
    { "type": "device", "device_id": "nd3f…", "dps": { "switch_1": false } },
    { "type": "notify", "channel": "push", "message": { "en": "Motion in hallway" } }
  ]
}
```

| Condition type | Fields | Evaluated from |
|----------------|--------|----------------|
| `device_dp` | `device_id`, `dp`, `op` (`==` `!=` `>` `>=` `<` `<=`), `value` | Shadow (state) and `device.state.changed` (edge) |
| `device_event` | `device_id`, `code`, optional `match` | `device.events` (edge only) |
| `device_online` | `device_id`, `value` | `device.presence.changed` |
| `schedule` | `spec` (same format as `automation.schedules.spec`) | `schedule.fired` (edge only) |
| `sun` | `event` (`sunrise`/`sunset`), `offset_min` | `schedule.fired` |
| `weather` | `metric` (`temp`, `humidity`, `condition`, `aqi`), `op`, `value` | Weather poller (per home location, every 15 min, cached per geo cell) |
| `geofence` | `user_id`, `event` (`arrive`/`leave`) | App-reported location events |

| Action type | Fields |
|-------------|--------|
| `device` | `device_id`, `dps` |
| `group` | `group_id`, `dps` |
| `delay` | `seconds` (1–86400) |
| `scene` | `rule_id` (run a scene) |
| `rule_enable` | `rule_id`, `enabled` |
| `notify` | `channel` (`push`/`sms`), localised `message` |
| `webhook` | `webhook_id` (partner integrations) |

### 9.2 Evaluation semantics

- **Edge-triggered:** a rule fires when a triggering event makes the condition set *become* true (`match:any` → the event's own condition is true; `match:all` → the event's condition is true and every other condition is true right now per the shadow). A sensor sitting in one state does not re-fire every report.
- **Preconditions** are checked in the home's timezone.
- **Delays:** actions after a `delay` are saved as a `delayed_action` row in `automation.schedules` carrying the run ID. Survives restarts.
- **Re-trigger while running** (`run_mode`): `restart` (default) cancels the pending delayed actions and starts over ("light off 5 min after the *last* motion"); `single` ignores new triggers until the run ends; `parallel` starts an independent run.
- **Safety:** loop guard via `nestapcause` (§2.3); per-rule limit of 1 run per 2 s and 120 per hour; a disabled or deleted rule cancels its pending delayed actions.
- **Execution:** actions call `command.Execute` in parallel (keeping order across `delay`s). Results go into `automation.runs` (shown in the app's log).

### 9.3 Local (gateway) execution

When every condition and action device of a rule is a sub-device of the same gateway, and the conditions are only `device_dp`/`device_event`/`schedule`, the rule is saved with `execution = 'local'`. It's compiled to a compact form and pushed via `down/rule/sync`. The gateway runs it with no internet, and the cloud only shows its run reports.

| Endpoint | Description |
|----------|-------------|
| `GET/POST /v1/homes/{id}/rules`, `GET/PATCH/DELETE /v1/rules/{id}` | CRUD (`?kind=scene` / `automation`) |
| `POST /v1/rules/{id}/run` | Run a scene (tap-to-run) |
| `PUT /v1/rules/{id}/enabled` | Enable/disable |
| `GET /v1/rules/{id}/runs` | Run log (from history) |

## 10. scheduler

**Purpose:** all time-based triggers: device timers, countdowns, schedule/sun conditions and delayed actions.

- Workers poll `automation.schedules` with `FOR UPDATE SKIP LOCKED` every second (see [03-database.md §4.6](03-database.md#46-scheduling-without-a-separate-queue)).
- `device_timer` rows run their `actions` straight through `command.Execute`. `rule` and `delayed_action` rows emit `schedule.fired` for the automation engine.
- Recomputes `next_run_at` in the schedule's timezone. Sun times come from the home's lat/long (on `home.updated`, every sun row in that home is recomputed).
- Devices with the `timer_local` capability also get their timers through `rpc set_timers`, so they keep running when offline. The cloud copy then exists for display and is not executed (`spec.local = true`).
- Missed runs (worker downtime): run if late by ≤ 5 min, skip and log otherwise. A morning light shouldn't switch on at noon.

| Endpoint | Description |
|----------|-------------|
| `GET/POST /v1/devices/{id}/timers`, `PATCH/DELETE /v1/timers/{id}` | Device timers |
| `GET/POST /v1/groups/{id}/timers` | Group timers |

Countdowns are DPs (`countdown_1`) handled by the device itself. No cloud job is needed.

## 11. history

**Purpose:** write and serve time-series data.

- **Writer:** consumes state/presence/events/command results/automation runs/audit. Maps each to its hypertable and batches with `COPY`. Respects the per-DP `report_policy.history` (`change` = every change, `sample` = at most every 5 min, `off`). Energy DPs are normalised into `energy_samples` (`add_ele` → `energy_wh_delta`).
- **Reader API:**

| Endpoint | Description |
|----------|-------------|
| `GET /v1/devices/{id}/history?dp=switch_1&from&to` | DP log (device activity screen) |
| `GET /v1/devices/{id}/energy?granularity=hour\|day\|month&tz` | Device energy |
| `GET /v1/homes/{id}/energy?granularity=…` | Home total + per-device breakdown |
| `GET /v1/devices/{id}/connectivity` | Online/offline timeline |
| `GET /v1/homes/{id}/logs` | Combined activity feed (commands, automations, alarms) |

## 12. realtime

**Purpose:** push live updates to apps.

- The app opens `wss://rt.{region}.nestap.io/v1/stream` with its JWT, then sends `{"op":"subscribe","home_id":"…"}`. Membership is checked via home gRPC (cached).
- A *fan-out* consumer group reads Kafka and publishes compact messages to Redis channel `rt:home:{homeId}`. Each WebSocket pod subscribes only to the channels of homes it has clients for.
- Messages: `state` (`{device_id, version, changed}`), `presence`, `command_result`, `device_added`/`device_removed`, `ota_progress`, `rule_run`, `home_changed`.
- Clients send `{"op":"resume","home_id":…,"versions":{deviceId:ver}}` after reconnecting. The server replies with fresh shadows for devices whose version moved.
- Ping every 30 s. Each pod handles ~50k connections. Pods scale on connection count.

## 13. notification

**Purpose:** deliver messages to people.

- Consumes `notification.requests` (from automations, OTA, home invites) and derives alarms itself from `device.events` (thing-model events flagged `notify: true`) and `device.presence.changed` (offline alerts, if the user enabled them).
- Fan-out to home members filtered by `notify.preferences` and quiet hours (alarms ignore quiet hours).
- Channels: FCM (Android), APNs (iOS, token-based auth per white-label app), SMS (pluggable provider with a local gateway for Bangladesh plus Twilio as fallback), email (SES/SMTP).
- Every message also goes into `notify.messages` (message center). Dedup key per `(user, device, code)` over 60 s stops alarm storms.
- Invalid push tokens (APNs 410 / FCM UNREGISTERED) are deleted.

| Endpoint | Description |
|----------|-------------|
| `POST /v1/push-tokens`, `DELETE …/{token}` | Register the device's push token |
| `GET /v1/messages?category=`, `POST /v1/messages/read` | Message center |
| `GET/PUT /v1/notification-settings` | Preferences, quiet hours |

## 14. ota

**Purpose:** firmware lifecycle and rollouts.

- **Upload** (vendor console): image to S3, server computes SHA-256, an offline signing step produces the Ed25519 signature (the private key never touches the cloud), then status `testing`.
- **Test:** a campaign targeting a device whitelist.
- **Campaign:** staged rollout (for example 1% → 10% → 50% → 100%). The next stage starts after `stage_wait_h` only if the failure rate is below `max_failure_pct`, otherwise the campaign auto-pauses. Optional night-time install window in the device's timezone.
- **Offer:** when a device is online (on `device.presence.changed` and `sys/hello`), the job is `pending` and the device is eligible (`from_version`, `min_from_version_code`) → publish `down/ota/upgrade` with a 1-hour signed URL from the CDN.
- **Modes:** `silent` (device installs on its own), `notify` (the user taps "Update" in the app → `POST /v1/devices/{id}/firmware/upgrade`), `forced` (security fixes; also blocks control until updated if the vendor requires it).
- **Progress:** `up/ota/progress` → `ota.jobs` + `ota.progress`. Success is confirmed when `sys/hello` reports the new version within 15 min of `rebooting`.

| Endpoint | Description |
|----------|-------------|
| `GET /v1/devices/{id}/firmware` | Current versions + available upgrade |
| `POST /v1/devices/{id}/firmware/upgrade` | User-triggered upgrade |
| `POST /vendor/v1/firmwares`, `POST /vendor/v1/campaigns`, `PATCH …/{id}` (pause/resume/abort) | Vendor console |

## 15. integration

**Purpose:** voice assistants, partner Open API, webhooks.

- **Alexa Smart Home skill** and **Google Home cloud-to-cloud:** account linking through identity's OAuth2. Discovery maps category + thing model → platform capabilities (`catalog.categories.voice_traits`). Directives are executed via `command.Execute(wait=true)`. State changes are pushed to the Alexa Event Gateway / Google HomeGraph (`ReportState`), debounced at 1 per device per second.
- **Open API** (`/open/v1/...`): the same resources as the app API, for OAuth2 partner clients, with stricter rate limits.
- **Webhooks:** signed (`X-Nestap-Signature: sha256=…`) POSTs of selected events. Retries with exponential backoff for 24 h. Auto-disabled after 50 consecutive failures.
- **Matter (later):** a Matter bridge runs on Nestap gateways and exposes sub-devices locally. No cloud component beyond the existing registry.

## 16. connector

**Purpose:** bring devices that live on another vendor's cloud into Nestap. Phase 1 provider: **Tuya**. Full design in [06-device-compatibility.md](06-device-compatibility.md).

- **Session API:** creates or loads the hidden Tuya UID user and Tuya home for a Nestap user/home, and returns the SDK login the app needs for pairing.
- **Import:** `POST /v1/devices/import {provider, external_id, room_id}` reads Tuya device info, specification and status, resolves a `catalog.device_profiles` match (auto-importing a category profile if needed), and asks device-registry to create the device with `transport = 'tuya_cloud'`.
- **Uplink worker:** consumes the Tuya message service (one consumer per Tuya project, resuming from `connector.cursors`), maps Tuya codes to Nestap codes, and publishes to `device.uplink` / `device.lifecycle` with header `transport=tuya_cloud`.
- **Downlink:** gRPC `SendCommand(device_id, codes)` → Tuya OpenAPI device command, with a token bucket per Tuya project so API quota is never exceeded.
- **Sync:** `home.member.*` → Tuya home members; `device.unbound` → remove from the Tuya home; Tuya "device removed" → registry unbind.
- **Credentials:** Tuya project access ID/secret in Vault; per-user SDK secrets envelope-encrypted in `connector.user_links`.

Adding another cloud provider later (for example eWeLink) means a new adapter inside this service, not a new pipeline.

## 17. Cross-cutting libraries (`pkg/`)

| Package | Contents |
|---------|----------|
| `pkg/thingmodel` | Thing-model types, cache, DP validation, id↔code mapping, scaling |
| `pkg/mqttproto` | Topic builders/parsers, envelope types, downlink publisher pool |
| `pkg/events` | CloudEvents envelope, Kafka producer/consumer helpers, outbox relay |
| `pkg/authz` | Permission resolution + Redis cache, JWT verification middleware |
| `pkg/crypto` | Envelope encryption (Vault/KMS), HMAC helpers, AES-GCM for activation payloads |
| `pkg/observability` | OpenTelemetry setup, structured logging (`slog`), Prometheus metrics |
| `pkg/httpx` | Error format, idempotency middleware, pagination, request IDs |
