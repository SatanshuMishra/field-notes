import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sections/data_section.dart';
import 'sections/journal_section.dart';
import 'sections/reminders_sound_section.dart';
import 'sections/sync_storage_section.dart';
import 'spell_check_availability.dart';
import 'widgets/settings_notice.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _notice;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showNotice(String message) {
    if (!mounted) {
      return;
    }
    setState(() => _notice = message);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _dismissNotice() {
    if (!mounted) {
      return;
    }
    setState(() => _notice = null);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AppSettings> settings = ref.watch(appSettingsProvider);
    return ColoredBox(
      color: Palette.page,
      child: settings.when(
        loading: _buildLoading,
        error: (Object error, StackTrace stackTrace) => _buildError(),
        data: _buildSections,
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CrossHatchPlaceholder(width: 28, height: 28),
    );
  }

  Widget _buildError() {
    return Center(
      child: StickerCard(
        surface: Palette.cardBright,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Your settings could not be loaded.',
              style: TypographyTokens.bodySans,
            ),
            const SizedBox(height: 16),
            StickerButton(
              label: 'Try again',
              variant: StickerButtonVariant.secondary,
              onPressed: () => ref.invalidate(appSettingsProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSections(AppSettings settings) {
    final String? notice = _notice;
    final SpellCheckAvailability spellCheckAvailability =
        ref.watch(spellCheckAvailabilityProvider).value ??
        SpellCheckAvailability.available;
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Text('Settings', style: TypographyTokens.titleSerif),
        const SizedBox(height: 16),
        if (notice != null) ...<Widget>[
          SettingsNotice(message: notice, onDismiss: _dismissNotice),
          const SizedBox(height: 16),
        ],
        SyncStorageSection(
          storageMode: ref.watch(settingsRepositoryProvider).storageMode,
        ),
        const SizedBox(height: 16),
        RemindersSoundSection(
          settings: settings,
          onFeedback: _showNotice,
        ),
        const SizedBox(height: 16),
        JournalSection(
          settings: settings,
          onFeedback: _showNotice,
          spellCheckAvailability: spellCheckAvailability,
        ),
        const SizedBox(height: 16),
        DataSection(onFeedback: _showNotice),
      ],
    );
  }
}
