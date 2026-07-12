import 'package:flutter/material.dart';

import 'shell/app_shell.dart';
import 'theme/app_theme.dart';

class FieldNotesApp extends StatelessWidget {
  const FieldNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Field Notes',
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(),
      home: const AppShell(),
    );
  }
}
