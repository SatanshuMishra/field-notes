import 'dart:io';

import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';

AppDatabase newTestDatabase() => AppDatabase(NativeDatabase.memory());

Future<Directory> newTempRoot() => Directory.systemTemp.createTemp('fn_media');
