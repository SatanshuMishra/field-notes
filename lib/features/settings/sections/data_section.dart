import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings_data_controller.dart';
import '../settings_feedback.dart';
import '../settings_providers.dart';
import '../widgets/delete_all_dialog.dart';

typedef DeleteAllConfirmer = Future<bool> Function(BuildContext context);

class DataSection extends ConsumerStatefulWidget {
  const DataSection({
    super.key,
    required this.onFeedback,
    this.confirmDelete = confirmDeleteAll,
  });

  final SettingsFeedbackSink onFeedback;
  final DeleteAllConfirmer confirmDelete;

  @override
  ConsumerState<DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends ConsumerState<DataSection> {
  bool _exporting = false;
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Data',
      children: <Widget>[
        SettingsFieldRow(
          label: 'Export',
          description: 'Save a zip of every entry and photo.',
          control: StickerButton(
            label: 'Export…',
            variant: StickerButtonVariant.secondary,
            onPressed: _exporting ? null : _runExport,
          ),
        ),
        SettingsFieldRow(
          label: 'Delete all',
          description: 'Erase every entry, photo, and mood on this device.',
          control: StickerButton(
            label: 'Delete all…',
            variant: StickerButtonVariant.danger,
            onPressed: _deleting ? null : _runDeleteAll,
          ),
        ),
      ],
    );
  }

  Future<void> _runExport() async {
    if (_exporting) {
      return;
    }
    setState(() => _exporting = true);
    try {
      final SettingsDataController controller =
          await ref.read(settingsDataControllerProvider.future);
      final DataActionResult result = await controller.export();
      if (!mounted) {
        return;
      }
      _report(result);
    } catch (error) {
      debugPrint('Settings export failed: $error');
      if (mounted) {
        widget.onFeedback('Export failed. Nothing was written.');
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _runDeleteAll() async {
    if (_deleting) {
      return;
    }
    setState(() => _deleting = true);
    try {
      final bool confirmed = await widget.confirmDelete(context);
      if (!mounted || !confirmed) {
        return;
      }
      final SettingsDataController controller =
          await ref.read(settingsDataControllerProvider.future);
      final DataActionResult result = await controller.deleteAll();
      if (!mounted) {
        return;
      }
      _report(result);
    } catch (error) {
      debugPrint('Settings delete-all failed: $error');
      if (mounted) {
        widget.onFeedback('Delete all failed. Your journal was not changed.');
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  void _report(DataActionResult result) {
    switch (result) {
      case DataActionSucceeded(:final String message):
        widget.onFeedback(message);
      case DataActionFailed(:final String message):
        widget.onFeedback(message);
      case DataActionDismissed():
        return;
    }
  }
}
