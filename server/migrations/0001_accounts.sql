CREATE TABLE accounts (
  id TEXT PRIMARY KEY NOT NULL,
  note TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('active', 'suspended', 'erased')),
  current_epoch INTEGER NOT NULL,
  recovery_sign_public_key BLOB NOT NULL UNIQUE,
  recovery_box_public_key BLOB NOT NULL,
  recovery_box_certificate BLOB NOT NULL,
  recovery_epoch_one_copy BLOB NOT NULL,
  created_at INTEGER NOT NULL
) STRICT;

CREATE TABLE invites (
  id TEXT PRIMARY KEY NOT NULL,
  code_hash TEXT NOT NULL UNIQUE,
  note TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  used_at INTEGER,
  revoked_at INTEGER,
  account_id TEXT
) STRICT;

CREATE TABLE devices (
  id TEXT PRIMARY KEY NOT NULL,
  account_id TEXT NOT NULL,
  sign_public_key BLOB NOT NULL,
  box_public_key BLOB NOT NULL,
  certificate BLOB NOT NULL,
  encrypted_name BLOB NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('active', 'removed', 'erased')),
  created_at INTEGER NOT NULL,
  last_seen_at INTEGER NOT NULL
) STRICT;

CREATE INDEX devices_account ON devices (account_id);

CREATE TABLE challenges (
  id TEXT PRIMARY KEY NOT NULL,
  subject TEXT NOT NULL,
  nonce TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  used INTEGER NOT NULL DEFAULT 0
) STRICT;

CREATE TABLE sessions (
  token_hash TEXT PRIMARY KEY NOT NULL,
  device_id TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('session', 'upload')),
  expires_at INTEGER NOT NULL
) STRICT;

CREATE INDEX sessions_device ON sessions (device_id);

CREATE TABLE epoch_rotations (
  account_id TEXT NOT NULL,
  epoch INTEGER NOT NULL,
  signer_device_id TEXT NOT NULL,
  signature BLOB,
  PRIMARY KEY (account_id, epoch)
) STRICT;

CREATE TABLE epoch_deliveries (
  account_id TEXT NOT NULL,
  epoch INTEGER NOT NULL,
  recipient TEXT NOT NULL,
  sealed BLOB NOT NULL,
  signature BLOB NOT NULL,
  PRIMARY KEY (account_id, epoch, recipient)
) STRICT;

CREATE TABLE relay_meta (
  key TEXT PRIMARY KEY NOT NULL,
  value BLOB NOT NULL
) STRICT;

INSERT INTO relay_meta (key, value) VALUES ('generation', randomblob(16));
