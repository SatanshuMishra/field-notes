import 'package:fake_async/fake_async.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/today/today_memory.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/features/today/today_week.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

Day _day({required String date, Mood? mood}) =>
    Day(id: 'day-$date', date: date, mood: mood, createdAt: 0, updatedAt: 0);

class _StubJournalRepository implements JournalRepository {
  _StubJournalRepository(this.days);

  final List<Day> days;
  final List<({int month, int day})> queries = <({int month, int day})>[];

  @override
  Future<List<Day>> onThisDay({required int month, required int day}) async {
    queries.add((month: month, day: day));
    return days;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container(List<Override> overrides) {
  final ProviderContainer container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}

void _returnToForeground() {
  final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.instance;
  addTearDown(binding.resetInternalState);
  binding
    ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
    ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

List<String> _listenToTodayDate(ProviderContainer container) {
  final List<String> seen = <String>[];
  container.listen<String>(
    todayDateProvider,
    (String? _, String date) => seen.add(date),
    fireImmediately: true,
  );
  return seen;
}

void main() {
  test('todayDate derives the date key from the clock', () {
    final ProviderContainer container = _container(<Override>[
      todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 19, 21, 30)),
    ]);

    expect(container.read(todayDateProvider), '2026-07-19');
  });

  test(
    'thisWeekCells attaches live day moods to the week-start window',
    () async {
      final ProviderContainer container = _container(<Override>[
        todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 22, 9)),
        weekStartProvider.overrideWithValue(WeekStart.monday),
        allDaysProvider.overrideWith(
          (Ref ref) => Stream<List<Day>>.value(<Day>[
            _day(date: '2026-07-22', mood: Mood.happy),
          ]),
        ),
      ]);

      final ProviderSubscription<AsyncValue<List<Day>>> sub = container.listen(
        allDaysProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await pumpEventQueue();

      final List<TodayWeekCell> cells = container.read(thisWeekCellsProvider);
      expect(cells.length, 7);
      expect(cells.first.date, '2026-07-20');
      expect(cells.first.weekdayLabel, 'Mon');
      expect(cells.first.mood, isNull);
      expect(cells[2].date, '2026-07-22');
      expect(cells[2].isToday, isTrue);
      expect(cells[2].mood, Mood.happy);
    },
  );

  test('onThisDayMemory selects a past-year day from the repository', () async {
    final _StubJournalRepository repository = _StubJournalRepository(<Day>[
      _day(date: '2026-07-19', mood: Mood.happy),
      _day(date: '2024-07-19', mood: Mood.calm),
    ]);
    final ProviderContainer container = _container(<Override>[
      todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 19, 9)),
      journalRepositoryProvider.overrideWithValue(repository),
    ]);

    final OnThisDayMemory? memory = await container.read(
      onThisDayMemoryProvider.future,
    );

    expect(repository.queries, <({int month, int day})>[(month: 7, day: 19)]);
    expect(memory?.day.date, '2024-07-19');
    expect(memory?.yearsAgo, 2);
  });

  test('onThisDayMemory yields null when nothing matches', () async {
    final ProviderContainer container = _container(<Override>[
      todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 19, 9)),
      journalRepositoryProvider.overrideWithValue(
        _StubJournalRepository(const <Day>[]),
      ),
    ]);

    expect(await container.read(onThisDayMemoryProvider.future), isNull);
  });

  test('todayDate moves to the new day once the clock passes midnight', () {
    fakeAsync((FakeAsync async) {
      final DateTime start = DateTime(2026, 11, 9, 23, 58);
      final ProviderContainer container = _container(<Override>[
        todayClockProvider.overrideWithValue(() => start.add(async.elapsed)),
      ]);
      final List<String> seen = _listenToTodayDate(container);

      async.elapse(const Duration(minutes: 1, seconds: 59));
      expect(seen, <String>['2026-11-09']);

      async.elapse(const Duration(seconds: 1));
      expect(seen, <String>['2026-11-09', '2026-11-10']);

      async.elapse(const Duration(hours: 23, minutes: 59, seconds: 59));
      expect(seen, <String>['2026-11-09', '2026-11-10']);

      async.elapse(const Duration(seconds: 1));
      expect(seen, <String>['2026-11-09', '2026-11-10', '2026-11-11']);
    });
  });

  test('todayDate moves on return to the foreground when the clock jumped '
      'past midnight while no timer fired', () {
    fakeAsync((FakeAsync async) {
      DateTime now = DateTime(2026, 11, 9, 22);
      final ProviderContainer container = _container(<Override>[
        todayClockProvider.overrideWithValue(() => now),
      ]);
      final List<String> seen = _listenToTodayDate(container);

      _returnToForeground();
      async.elapse(Duration.zero);
      expect(seen, <String>['2026-11-09']);

      now = DateTime(2026, 11, 10, 7, 30);
      async.elapse(Duration.zero);
      expect(seen, <String>['2026-11-09']);

      _returnToForeground();
      async.elapse(Duration.zero);
      expect(seen, <String>['2026-11-09', '2026-11-10']);
      expect(container.read(todayDateProvider), '2026-11-10');
    });
  });

  test('the week and the memory move to the new day with todayDate', () {
    fakeAsync((FakeAsync async) {
      final DateTime start = DateTime(2026, 11, 15, 23, 58);
      final ProviderContainer container = _container(<Override>[
        todayClockProvider.overrideWithValue(() => start.add(async.elapsed)),
        weekStartProvider.overrideWithValue(WeekStart.monday),
        allDaysProvider.overrideWith(
          (Ref ref) => Stream<List<Day>>.value(<Day>[
            _day(date: '2025-11-15', mood: Mood.calm),
            _day(date: '2024-11-16', mood: Mood.happy),
          ]),
        ),
      ]);
      final List<String> todayCells = <String>[];
      container.listen<List<TodayWeekCell>>(
        thisWeekCellsProvider,
        (List<TodayWeekCell>? _, List<TodayWeekCell> cells) => todayCells.add(
          cells.singleWhere((TodayWeekCell cell) => cell.isToday).date,
        ),
        fireImmediately: true,
      );
      container.listen<AsyncValue<OnThisDayMemory?>>(
        onThisDayMemoryProvider,
        (AsyncValue<OnThisDayMemory?>? _, AsyncValue<OnThisDayMemory?> _) {},
      );

      async.elapse(Duration.zero);
      expect(todayCells.last, '2026-11-15');
      expect(container.read(thisWeekCellsProvider).first.date, '2026-11-09');
      expect(
        container.read(onThisDayMemoryProvider).value?.day.date,
        '2025-11-15',
      );
      final int settled = todayCells.length;

      async.elapse(const Duration(minutes: 2));
      expect(todayCells.skip(settled), <String>['2026-11-16']);
      expect(container.read(thisWeekCellsProvider).first.date, '2026-11-16');
      expect(
        container.read(onThisDayMemoryProvider).value?.day.date,
        '2024-11-16',
      );
    });
  });
}
