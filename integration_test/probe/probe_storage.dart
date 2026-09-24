import 'dart:io';

import 'package:path/path.dart' as p;

const String _dataFolder = 'data';
const String _documentsFolder = 'documents';
const String _mediaFolder = 'media';
const String _draftsFolder = 'drafts';
const String _databaseFile = 'field_notes.sqlite';
const String _scenarioMarker = 'scenario.txt';

final class ProbeStorage {
  const ProbeStorage._({
    required this.base,
    required this.scenario,
    required this.wiped,
  });

  static Future<ProbeStorage> open(Directory base) async {
    final File marker = File(p.join(base.path, _scenarioMarker));
    final String scenario = await marker.exists()
        ? await marker.readAsString()
        : '';
    final ProbeStorage storage = ProbeStorage._(
      base: base,
      scenario: scenario,
      wiped: false,
    );
    await storage._createFolders();
    return storage;
  }

  final Directory base;
  final String scenario;
  final bool wiped;

  Directory get root => Directory(p.join(base.path, _dataFolder));

  Directory get documents => Directory(p.join(root.path, _documentsFolder));

  String get database => p.join(documents.path, _databaseFile);

  Directory get media => Directory(p.join(documents.path, _mediaFolder));

  Directory get drafts => Directory(p.join(documents.path, _draftsFolder));

  Future<ProbeStorage> begin(String scenario, {bool fresh = false}) async {
    if (scenario == this.scenario && !fresh) {
      return ProbeStorage._(base: base, scenario: scenario, wiped: false);
    }
    final Directory data = root;
    if (await data.exists()) {
      await data.delete(recursive: true);
    }
    final ProbeStorage next = ProbeStorage._(
      base: base,
      scenario: scenario,
      wiped: true,
    );
    await next._createFolders();
    await File(p.join(base.path, _scenarioMarker)).writeAsString(scenario);
    return next;
  }

  Future<void> _createFolders() async {
    await media.create(recursive: true);
    await drafts.create(recursive: true);
  }
}
