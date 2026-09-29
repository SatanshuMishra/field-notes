import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_gate.g.dart';

enum OnboardingVisibility { hidden, shown }

@Riverpod(keepAlive: true)
class OnboardingGate extends _$OnboardingGate {
  @override
  Future<OnboardingVisibility> build() async {
    final SettingsRepository settings = ref.watch(settingsRepositoryProvider);
    final JournalRepository journal = ref.watch(journalRepositoryProvider);
    final OnboardingStatus? stored;
    final bool fresh;
    try {
      stored = (await settings.load()).onboardingStatus;
      fresh =
          stored == null &&
          !await settings.hasStoredValues() &&
          (await journal.watchAllDays().first).isEmpty;
    } catch (error) {
      debugPrint('Could not decide whether to show onboarding: $error');
      return OnboardingVisibility.hidden;
    }
    final OnboardingStatus status =
        stored ??
        await _record(
          settings,
          fresh ? OnboardingStatus.pending : OnboardingStatus.done,
        );
    return switch (status) {
      OnboardingStatus.done => OnboardingVisibility.hidden,
      OnboardingStatus.pending => OnboardingVisibility.shown,
    };
  }

  Future<void> complete() async {
    await ref
        .read(settingsRepositoryProvider)
        .setOnboardingStatus(OnboardingStatus.done);
    state = const AsyncData<OnboardingVisibility>(OnboardingVisibility.hidden);
  }

  Future<OnboardingStatus> _record(
    SettingsRepository settings,
    OnboardingStatus status,
  ) async {
    try {
      await settings.setOnboardingStatus(status);
    } catch (error) {
      debugPrint('Could not record the onboarding decision: $error');
    }
    return status;
  }
}
