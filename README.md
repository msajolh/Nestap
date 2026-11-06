# Nestap

Nestap is a cloud IoT platform for smart home devices: Wi-Fi, BLE and Zigbee switches, sockets, lights, curtains and sensors. It covers device onboarding, cloud and LAN control, scenes and automations, energy history, OTA updates, home sharing and voice-assistant integration, in the style of Tuya Smart.

This repository holds the platform architecture and, later, the backend code.

## Architecture documents

| # | Document | What it covers |
|---|----------|----------------|
| 1 | [System overview](docs/architecture/01-system-overview.md) | Goals, layers, technology choices, regions/cells, scaling, security, deployment phases |
| 2 | [MQTT protocol](docs/architecture/02-mqtt-protocol.md) | Broker setup, device authentication, topic tree, payloads, QoS, ACL, presence, gateways |
| 3 | [Database design](docs/architecture/03-database.md) | PostgreSQL, TimescaleDB, Redis and object storage: data ownership, ERD, retention |
| 4 | [Backend services](docs/architecture/04-backend-services.md) | Each service's job, the data it owns, its APIs and events, the Kafka topic catalog, conventions |
| 5 | [Key flows](docs/architecture/05-key-flows.md) | Sequence diagrams for pairing, control, state sync, automations, OTA and sharing |

## Schema files

| File | Database |
|------|----------|
| [db/postgres/001_core_schema.sql](db/postgres/001_core_schema.sql) | Core relational data (PostgreSQL 16) |
| [db/timescale/001_telemetry_schema.sql](db/timescale/001_telemetry_schema.sql) | Time-series history, energy, logs (TimescaleDB 2.x on PostgreSQL 16) |

## Planned repository layout

```
nestap/
├── api/                 # OpenAPI specs (public REST) and .proto files (internal gRPC)
├── services/            # one Go module per service (see 04-backend-services.md)
│   ├── identity/
│   ├── home/
│   ├── catalog/
│   ├── device-registry/
│   ├── device-connect/  # EMQX auth hooks
│   ├── shadow/
│   ├── command/
│   ├── automation/
│   ├── scheduler/
│   ├── history/
│   ├── realtime/
│   ├── notification/
│   ├── ota/
│   └── integration/
├── pkg/                 # shared libraries: thingmodel, mqttproto, events, authz, observability
├── db/                  # migrations (postgres/, timescale/)
├── deploy/              # Helm charts, EMQX config, Terraform
└── docs/
```
