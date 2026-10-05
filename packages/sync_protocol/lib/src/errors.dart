enum SyncErrorCode {
  unauthorized('unauthorized', 401),
  suspended('suspended', 403),
  unsupportedProtocol('unsupported_protocol', 426),
  inviteUsed('invite_used', 409),
  inviteExpired('invite_expired', 410),
  inviteInvalid('invite_invalid', 400),
  notFound('not_found', 404),
  storageFull('storage_full', 507),
  pairingExpired('pairing_expired', 410),
  journalErased('journal_erased', 410),
  deviceRemoved('device_removed', 401),
  staleEpoch('stale_epoch', 409),
  badRequest('bad_request', 400),
  forbidden('forbidden', 403);

  const SyncErrorCode(this.wireName, this.httpStatus);

  final String wireName;
  final int httpStatus;
}
