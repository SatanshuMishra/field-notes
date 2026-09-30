import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/features/garden/model/meadow_view_state.dart';
import 'package:field_notes/state/shell_navigation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container() {
  final ProviderContainer container = ProviderContainer();
  addTearDown(container.dispose);
  container.listen(meadowViewStateProvider, (_, _) {});
  container.listen(shellNavigationProvider, (_, _) {});
  return container;
}

void main() {
  test(
    'picking a past year opens its study and leaving the tab returns to this year',
    () {
      final ProviderContainer container = _container();
      final MeadowViewState view = container.read(
        meadowViewStateProvider.notifier,
      );

      view.openYear(2024, currentYear: 2026);
      expect(container.read(meadowViewStateProvider).studyYear, 2024);

      view.openYear(2026, currentYear: 2026);
      expect(container.read(meadowViewStateProvider).studyYear, isNull);

      container
          .read(shellNavigationProvider.notifier)
          .select(ShellDestination.garden);
      view.openYear(2024, currentYear: 2026);
      expect(container.read(meadowViewStateProvider).studyYear, 2024);

      container
          .read(shellNavigationProvider.notifier)
          .select(ShellDestination.today);
      expect(container.read(meadowViewStateProvider), const MeadowView());
    },
  );

  test('full screen keeps the year and growth point', () {
    final ProviderContainer container = _container();
    final MeadowViewState view = container.read(
      meadowViewStateProvider.notifier,
    );
    const MeadowFullScreenRequest request = MeadowFullScreenRequest(
      year: 2024,
      hourMinutes: null,
      growthPoint: 200,
    );

    container
        .read(shellNavigationProvider.notifier)
        .select(ShellDestination.garden);
    view.openFullScreen(request);
    final MeadowFullScreenRequest? open = container
        .read(meadowViewStateProvider)
        .fullScreen;
    expect(open, request);
    expect(open?.year, 2024);
    expect(open?.hourMinutes, isNull);
    expect(open?.growthPoint, 200);

    view.closeFullScreen();
    expect(container.read(meadowViewStateProvider).fullScreen, isNull);

    view.openFullScreen(request);
    container
        .read(shellNavigationProvider.notifier)
        .select(ShellDestination.today);
    expect(container.read(meadowViewStateProvider).fullScreen, isNull);
  });
}
