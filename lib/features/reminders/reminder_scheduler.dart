abstract interface class ReminderScheduler {
  Future<bool> ensurePermission();

  Future<void> schedule(DateTime at);

  Future<void> cancel();
}
