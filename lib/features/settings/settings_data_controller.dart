sealed class DataActionResult {
  const DataActionResult();
}

class DataActionSucceeded extends DataActionResult {
  const DataActionSucceeded(this.message);

  final String message;
}

class DataActionDismissed extends DataActionResult {
  const DataActionDismissed();
}

class DataActionFailed extends DataActionResult {
  const DataActionFailed(this.message);

  final String message;
}

abstract interface class SettingsDataController {
  Future<DataActionResult> export();

  Future<DataActionResult> deleteAll();

  Future<DataActionResult> reclaimSpace();
}
