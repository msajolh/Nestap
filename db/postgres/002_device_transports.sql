-- =============================================================================
-- Nestap 002 · Device transports and third-party connectors
-- See docs/architecture/06-device-compatibility.md
--
-- Devices can now reach Nestap through Tuya's cloud (Phase 1), a Nestap
-- gateway (Zigbee / Matter) or Nestap firmware over MQTT.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS connector;

-- -----------------------------------------------------------------------------
-- device.devices: transport + external identity
-- -----------------------------------------------------------------------------

ALTER TABLE device.devices
  ADD COLUMN transport text NOT NULL DEFAULT 'nestap_mqtt'
    CHECK (transport IN ('nestap_mqtt', 'tuya_cloud', 'gateway_zigbee', 'gateway_matter')),
  ADD COLUMN external_id text,                  -- Tuya devId, Matter node id, ...
  ADD COLUMN external_meta jsonb NOT NULL DEFAULT '{}';  -- e.g. {"tuya_product_id":"...","tuya_category":"kg"}

-- Cloud-connector devices have no Nestap license or MQTT secret, and must carry
-- the vendor's id. (The sub-device CHECK from 001 still applies to gateway_*.)
ALTER TABLE device.devices
  ADD CONSTRAINT devices_transport_identity_chk CHECK (
    CASE transport
      WHEN 'tuya_cloud'  THEN external_id IS NOT NULL AND license_uuid IS NULL AND secret_enc IS NULL
      WHEN 'nestap_mqtt' THEN external_id IS NULL
      ELSE true
    END
  );

-- one bound Nestap device per external device
CREATE UNIQUE INDEX devices_external_bound_idx ON device.devices (transport, external_id)
  WHERE status <> 'unbound' AND external_id IS NOT NULL;

-- -----------------------------------------------------------------------------
-- catalog.device_profiles: recognise a foreign device and map it to a product
-- -----------------------------------------------------------------------------

CREATE TABLE catalog.device_profiles (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider     text NOT NULL CHECK (provider IN ('tuya', 'zigbee', 'matter')),
  -- exact:    {"tuya_product_id":"keyu8xxxxxxx"} | {"zigbee_manufacturer":"_TZ3000_xxx","zigbee_model":"TS0002"}
  --           | {"matter_vendor_id":4417,"matter_product_id":32769}
  -- category: {"tuya_category":"kg"}
  match        jsonb NOT NULL,
  match_level  text  NOT NULL CHECK (match_level IN ('exact', 'category')),
  product_id   text  NOT NULL REFERENCES catalog.products (id),
  -- foreign code -> Nestap code, plus optional value transforms:
  -- {"switch_1":"switch_1","cur_power":"cur_power","Power":{"code":"switch_1","map":{"on":true,"off":false}}}
  dp_map       jsonb NOT NULL DEFAULT '{}',
  priority     integer NOT NULL DEFAULT 100,    -- lower wins when several profiles match
  source       text NOT NULL DEFAULT 'curated' CHECK (source IN ('curated', 'auto_imported')),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provider, match)
);
CREATE INDEX device_profiles_match_idx ON catalog.device_profiles USING gin (match);

-- -----------------------------------------------------------------------------
-- connector: hidden third-party identities behind Nestap users and homes
-- (service: connector)
-- -----------------------------------------------------------------------------

CREATE TABLE connector.user_links (
  user_id        uuid NOT NULL,                 -- -> identity.users
  provider       text NOT NULL CHECK (provider IN ('tuya')),
  external_uid   text NOT NULL,                 -- Tuya UID-login user id (= Nestap user id)
  secret_enc     bytea NOT NULL,                -- Tuya SDK login secret, envelope-encrypted
  region         text NOT NULL,                 -- Tuya data centre
  status         text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'error', 'deleted')),
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, provider),
  UNIQUE (provider, external_uid)
);

CREATE TABLE connector.home_links (
  home_id           uuid NOT NULL,              -- -> home.homes
  provider          text NOT NULL CHECK (provider IN ('tuya')),
  external_home_id  text NOT NULL,              -- Tuya home id
  owner_user_id     uuid NOT NULL,              -- Nestap user whose Tuya identity owns the Tuya home
  members_synced_at timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (home_id, provider),
  UNIQUE (provider, external_home_id)
);

-- Resume points for message-queue consumers (Tuya message service subscription).
CREATE TABLE connector.cursors (
  provider    text NOT NULL,
  stream      text NOT NULL,
  position    text NOT NULL,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (provider, stream)
);

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['catalog.device_profiles', 'connector.user_links', 'connector.home_links'] LOOP
    EXECUTE format(
      'CREATE TRIGGER touch_updated_at BEFORE UPDATE ON %s FOR EACH ROW EXECUTE FUNCTION infra.touch_updated_at()', t);
  END LOOP;
END $$;
