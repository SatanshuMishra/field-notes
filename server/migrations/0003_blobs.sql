CREATE TABLE blobs (
  account_id TEXT NOT NULL,
  name TEXT NOT NULL,
  size INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  unused_since INTEGER,
  PRIMARY KEY (account_id, name)
) STRICT;

CREATE INDEX blobs_unused ON blobs (unused_since) WHERE unused_since IS NOT NULL;

CREATE TABLE uploads (
  id TEXT PRIMARY KEY NOT NULL,
  account_id TEXT NOT NULL,
  name TEXT NOT NULL,
  total_bytes INTEGER NOT NULL,
  part_size INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  assembling INTEGER NOT NULL DEFAULT 0,
  assembled INTEGER NOT NULL DEFAULT 0
) STRICT;

CREATE INDEX uploads_account ON uploads (account_id);

CREATE TABLE upload_parts (
  upload_id TEXT NOT NULL,
  part_index INTEGER NOT NULL,
  PRIMARY KEY (upload_id, part_index)
) STRICT;
