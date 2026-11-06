# 05 · Key Flows

## 1. Device pairing and activation

Supported pairing modes (from the app's point of view they differ only in step 3):

| Mode | How Wi-Fi credentials reach the device |
|------|----------------------------------------|
| **BLE** (preferred, `wifi_ble` products) | App writes SSID, password and token to a GATT characteristic, encrypted with an ECDH-derived session key |
| **AP mode** | Device starts a `Nestap-XXXX` SoftAP. The app joins it and POSTs the data to `192.168.4.1` |
| **EZ mode** | Legacy broadcast-length encoding, only for old modules without BLE |

```mermaid
sequenceDiagram
  autonumber
  actor U as User
  participant A as App
  participant API as device-registry
  participant R as Redis
  participant D as Device
  participant ACT as Activation API
  participant PG as PostgreSQL
  participant B as EMQX
  participant RT as realtime

  U->>A: Add device (home, room)
  A->>API: POST /v1/pairing/tokens {home_id, room_id}
  API->>R: SET pair:{token} (TTL 10 min)
  API-->>A: {token:"AP7Kq2Xz9w", expires_in:600}
  A->>D: BLE/AP: {ssid, password, token}
  D->>D: Join Wi-Fi, region from token prefix
  D->>ACT: POST /v1/device/activate {uuid, pid, token, fw, mac, ts, sign=HMAC(authKey, uuid|token|ts)}
  ACT->>PG: Load license, check status/batch, verify sign
  ACT->>R: Check + read pair:{token}
  ACT->>PG: TX: insert devices (new id), shadows, outbox(device.activated)<br/>mark previous binding of this license 'unbound'
  ACT->>R: SADD pair:{token}:devices {deviceId}
  ACT-->>D: AES-GCM(authKey){deviceId, deviceSecret, localKey, mqtt_host, time, tz}
  D->>B: CONNECT (HMAC credentials)
  D->>B: up/sys/hello, up/prop/report (full)
  Note over API,RT: outbox → device.registry → realtime
  RT-->>A: device_added
  A->>API: GET /v1/pairing/tokens/{token}/devices (fallback poll)
  A-->>U: "Device added"
```

Failure handling:

| Case | Behaviour |
|------|-----------|
| Token expired/unknown | `410` to device. The device returns to pairing mode and the app shows "Timed out, try again" |
| License revoked or signature bad | `403` + audit log + security metric. The device blinks an error pattern |
| License already bound elsewhere | Allowed (the factory-reset button press proves physical access). The old binding is unbound and its owner gets a "device removed" message |
| Activation response lost (device retries) | Same `(uuid, token)` within the token TTL returns the same credentials (idempotent) |

## 2. App controls a device

```mermaid
sequenceDiagram
  autonumber
  participant A as App
  participant GW as API gateway
  participant C as command
  participant R as Redis
  participant B as EMQX
  participant D as Device
  participant K as Kafka
  participant S as shadow
  participant RT as realtime

  A->>GW: POST /v1/devices/nd3f/commands {dps:{switch_1:false}}
  GW->>C: JWT verified, rate limit OK
  C->>R: perm:{user}:nd3f, dev:meta:nd3f, dev:online:nd3f
  C->>C: Thing-model validate → {"1":false}
  C->>B: PUBLISH nt/v1/nd3f/down/prop/set (QoS1, expiry 30s)
  C->>R: SET cmd:c_01J (60s)
  C-->>A: 202 {command_id}
  B->>D: prop/set
  D->>D: Relay off
  D->>B: up/prop/set/ack {id, code:0}
  D->>B: up/prop/report {dps:{"1":false}, src:"cloud"}
  B->>K: device.uplink (ack, report)
  K->>C: ack → command.results (acked, 140 ms)
  K->>S: report → Lua merge, version 122
  S->>K: device.state.changed
  K->>RT: → Redis rt:home:{id}
  RT-->>A: state {nd3f, v122, switch_1:false}
```

If no ack arrives within 10 s, command emits `timeout` and the app rolls back its optimistic UI with "Device not responding".

## 3. Physical button press → app, automations, history

```mermaid
sequenceDiagram
  autonumber
  participant D as Device
  participant B as EMQX
  participant K as Kafka
  participant S as shadow
  participant AU as automation
  participant H as history
  participant RT as realtime
  participant I as integration

  D->>B: up/prop/report {dps:{"1":true}, src:"local", seq:1844}
  B->>K: device.uplink
  K->>S: validate, merge, version++
  S->>K: device.state.changed {changed:{switch_1:true}}
  par fan-out (independent consumer groups)
    K->>AU: trg:{deviceId} lookup → matching rules
    K->>H: dp_history row (batched COPY)
    K->>RT: push to app
    K->>I: Alexa/Google ReportState
  end
```

## 4. Automation with a delay

"When the hallway PIR detects motion after dark, turn the light on, then off after 5 minutes."

```mermaid
sequenceDiagram
  autonumber
  participant K as Kafka
  participant AU as automation engine
  participant R as Redis
  participant C as command
  participant PG as PostgreSQL
  participant SC as scheduler

  K->>AU: device.state.changed (PIR nd9a, pir_state=pir)
  AU->>R: trg:nd9a → [rule_0193…]
  AU->>AU: Edge check, preconditions (18:00–06:00 home tz), rate limit, loop guard
  AU->>C: Execute(nd3f, switch_1=true, cause=rule_0193)
  AU->>PG: INSERT schedules (delayed_action, next_run_at=now+300s, remaining actions)
  AU->>K: automation.runs (running)
  Note over SC: 5 minutes later
  SC->>PG: Claim due rows (SKIP LOCKED)
  SC->>K: schedule.fired {delayed_action, run_id}
  K->>AU: Continue run
  AU->>C: Execute(nd3f, switch_1=false)
  AU->>K: automation.runs (succeeded)
```

If motion fires again while the delay is pending, the default `restart` mode replaces the pending delayed action, so the light stays on for 5 minutes after the *last* motion. The rule's `run_mode` can be `restart` (default), `single` (ignore new triggers while running) or `parallel`.

## 5. OTA staged rollout

```mermaid
sequenceDiagram
  autonumber
  actor V as Vendor
  participant O as ota
  participant S3 as S3/CDN
  participant B as EMQX
  participant D as Device
  participant A as App

  V->>O: Upload 1.5.0 (signed offline)
  O->>S3: Store image
  V->>O: Create campaign (1%→10%→50%→100%, notify mode)
  O->>O: Select stage-1 devices → ota.jobs (pending)
  Note over O,D: Device online (presence event or sys/hello)
  O->>B: down/ota/upgrade {url (signed, 1h), sha256, sig, mode:notify}
  O->>A: push "Update available" (notify mode)
  A->>O: POST /v1/devices/{id}/firmware/upgrade
  O->>B: down/rpc/req {method:"ota_start", job}
  D->>S3: HTTPS GET image (range requests, resumable)
  D->>B: up/ota/progress downloading 0→100%
  D->>D: Verify SHA-256 + Ed25519, flash inactive slot, reboot
  D->>B: up/sys/hello {fw.main:"1.5.0"}
  B->>O: (via Kafka) mark job succeeded
  O->>O: Stage gate: failure rate < 3% after 24h → next stage
```

Devices use A/B partitions (or a bootloader with rollback). If the new image fails to connect within 3 boots, the bootloader rolls back and the next `sys/hello` reports the old version → job `failed: rollback`.

## 6. Remove device / factory reset

```mermaid
sequenceDiagram
  autonumber
  participant A as App
  participant REG as device-registry
  participant B as EMQX
  participant D as Device
  participant PG as PostgreSQL
  participant R as Redis

  A->>REG: DELETE /v1/devices/nd3f?reset=true
  REG->>B: down/rpc/req {method:"unbind"} (if online)
  D->>B: up/rpc/resp {code:0}
  D->>D: Wipe deviceId/secret/localKey, enter pairing mode
  REG->>PG: TX: status='unbound', null secrets, delete shares/group members,<br/>outbox(device.unbound)
  REG->>R: DEL dev:auth/meta/shadow, PUBLISH dev:revoked
  REG->>B: DELETE /api/v5/clients/nd3f (kick session)
  Note over REG: device.unbound → automation removes the device from rules,<br/>scheduler deletes timers, integration tells Alexa/Google
```

If the device is offline, the cloud side still unbinds. The device's next CONNECT fails auth, and it falls back to pairing mode.

## 7. Inviting a family member

```mermaid
sequenceDiagram
  autonumber
  actor O as Owner
  actor M as Member
  participant H as home
  participant N as notification
  participant RT as realtime

  O->>H: POST /v1/homes/{id}/invitations {role:"member", room_ids:[...]}
  H-->>O: {code:"K7Q2-9XZD", link}
  O-->>M: Share link (WhatsApp, SMS…)
  M->>H: POST /v1/invitations/K7Q2-9XZD/accept
  H->>H: TX: insert member, mark invitation, outbox(home.member.added)
  H->>N: (via Kafka) notify owner "M joined"
  H->>RT: home_changed → member's app loads the home
```
