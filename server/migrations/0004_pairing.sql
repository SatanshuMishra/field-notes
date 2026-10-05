CREATE TABLE mailboxes (
  id TEXT PRIMARY KEY NOT NULL,
  account_id TEXT NOT NULL,
  token_hash TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('open', 'joined', 'complete')),
  join_payload TEXT,
  complete_payload BLOB
) STRICT;

CREATE INDEX mailboxes_account ON mailboxes (account_id);

CREATE TABLE restore_tokens (
  token_hash TEXT PRIMARY KEY NOT NULL,
  account_id TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  used INTEGER NOT NULL DEFAULT 0
) STRICT;
