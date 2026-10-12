#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: sign_update.sh <private key PEM> <file>" >&2
  exit 64
fi

key="$1"
file="$2"
openssl="${OPENSSL:-openssl}"
ed25519_prefix='302a300506032b6570032100'

if [[ ! -f "$key" ]]; then
  echo "::error::No signing key at $key." >&2
  exit 1
fi

if [[ ! -f "$file" ]]; then
  echo "::error::No file to sign at $file." >&2
  exit 1
fi

if ! public="$("$openssl" pkey -in "$key" -pubout -outform DER 2>/dev/null | od -An -v -tx1 | tr -d ' \n')" || [[ -z "$public" ]]; then
  echo "::error::$openssl cannot read the private key $key; signing needs OpenSSL 3 (set OPENSSL to its path)." >&2
  exit 1
fi

if [[ ${#public} -ne 88 || "${public:0:24}" != "$ed25519_prefix" ]]; then
  echo "::error::$key is not an Ed25519 private key; create one with openssl genpkey -algorithm ed25519 (OpenSSL 3)." >&2
  exit 1
fi

signature="$("$openssl" pkeyutl -sign -rawin -inkey "$key" -in "$file" | base64 | tr -d '\r\n')"

if [[ ${#signature} -ne 88 ]]; then
  echo "::error::$openssl did not produce a 64-byte Ed25519 signature of $file." >&2
  exit 1
fi

printf '%s\n' "$signature"
