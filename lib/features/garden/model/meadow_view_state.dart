import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/state/shell_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'meadow_view_state.g.dart';

@immutable
class MeadowFullScreenRequest {
  const MeadowFullScreenRequest({
    required this.year,
    required this.hourMinutes,
    required this.growthPoint,
  });

  final int year;
  final int? hourMinutes;
  final int growthPoint;

  @override
  bool operator ==(Object other) =>
      other is MeadowFullScreenRequest &&
      other.year == year &&
      other.hourMinutes == hourMinutes &&
      other.growthPoint == growthPoint;

  @override
  int get hashCode => Object.hash(year, hourMinutes, growthPoint);
}

@immutable
class MeadowView {
  const MeadowView({this.studyYear, this.fullScreen});

  final int? studyYear;
  final MeadowFullScreenRequest? fullScreen;

  @override
  bool operator ==(Object other) =>
      other is MeadowView &&
      other.studyYear == studyYear &&
      other.fullScreen == fullScreen;

  @override
  int get hashCode => Object.hash(studyYear, fullScreen);
}

@Riverpod(keepAlive: true)
class MeadowViewState extends _$MeadowViewState {
  @override
  MeadowView build() {
    ref.listen<ShellDestination>(shellNavigationProvider, (
      ShellDestination? previous,
      ShellDestination next,
    ) {
      if (next != ShellDestination.garden) {
        state = const MeadowView();
      }
    });
    return const MeadowView();
  }

  void openYear(int year, {required int currentYear}) {
    state = MeadowView(
      studyYear: year == currentYear ? null : year,
      fullScreen: state.fullScreen,
    );
  }

  void backToThisYear() {
    state = MeadowView(fullScreen: state.fullScreen);
  }

  void openFullScreen(MeadowFullScreenRequest request) {
    state = MeadowView(studyYear: state.studyYear, fullScreen: request);
  }

  void closeFullScreen() {
    state = MeadowView(studyYear: state.studyYear);
  }
}
