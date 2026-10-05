CREATE TABLE records (
  account_id TEXT NOT NULL,
  record_key TEXT NOT NULL,
  seq INTEGER NOT NULL,
  epoch INTEGER NOT NULL,
  envelope BLOB NOT NULL,
  change_id TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (account_id, record_key)
) STRICT;

CREATE INDEX records_account_seq ON records (account_id, seq);

CREATE TABLE account_seqs (
  account_id TEXT PRIMARY KEY NOT NULL,
  last_seq INTEGER NOT NULL
) STRICT;

CREATE TABLE change_ids (
  account_id TEXT NOT NULL,
  change_id TEXT NOT NULL,
  seq INTEGER NOT NULL,
  PRIMARY KEY (account_id, change_id)
) STRICT;
