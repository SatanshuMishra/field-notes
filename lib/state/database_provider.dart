import 'package:field_notes/data/database/app_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_provider.g.dart';

@Riverpod(keepAlive: true)
AppDatabase database(Ref ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
}
