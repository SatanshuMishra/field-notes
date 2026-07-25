import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/entry_cards/playback/video_slots.dart';

void main() {
  late List<String> evicted;
  late List<String> freed;

  setUp(() {
    evicted = <String>[];
    freed = <String>[];
  });

  VideoSlotEviction evictionOf(String name) => () => evicted.add(name);

  VideoSlotFreedListener freedListener(String name) => () => freed.add(name);

  group('LruVideoSlots', () {
    test('grants a slot while the registry is under the cap', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 2);

      final VideoSlotToken? first = slots.acquire(onEvicted: evictionOf('a'));
      final VideoSlotToken? second = slots.acquire(onEvicted: evictionOf('b'));

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(first, isNot(same(second)));
      expect(evicted, isEmpty);
    });

    test('caps a default registry at the assumed decoder ceiling', () {
      final LruVideoSlots slots = LruVideoSlots();

      for (int index = 0;
          index < assumedConcurrentVideoDecoderCap;
          index += 1) {
        expect(
          slots.acquire(onEvicted: evictionOf('holder$index')),
          isNotNull,
        );
      }
      expect(evicted, isEmpty);

      expect(slots.acquire(onEvicted: evictionOf('overflow')), isNotNull);
      expect(evicted, <String>['holder0']);
    });

    test('reports whether a token still holds a slot', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 1);
      final LruVideoSlots other = LruVideoSlots(cap: 1);
      final VideoSlotToken? token = slots.acquire(onEvicted: evictionOf('a'));
      final VideoSlotToken? foreign =
          other.acquire(onEvicted: evictionOf('foreign'));
      expect(token, isNotNull);
      expect(foreign, isNotNull);

      expect(slots.holds(token), isTrue);
      expect(slots.holds(foreign), isFalse);
      expect(slots.holds(null), isFalse);

      slots.release(token);

      expect(slots.holds(token), isFalse);
    });

    test('evicts the least recently used unpinned holder at the cap', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 2);
      final VideoSlotToken? first = slots.acquire(onEvicted: evictionOf('a'));
      final VideoSlotToken? second = slots.acquire(onEvicted: evictionOf('b'));

      final VideoSlotToken? third = slots.acquire(onEvicted: evictionOf('c'));

      expect(third, isNotNull);
      expect(evicted, <String>['a']);
      expect(slots.holds(first), isFalse);
      expect(slots.holds(second), isTrue);
      expect(slots.holds(third), isTrue);
    });

    test('notifies only the evicted holder and only once', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 3);
      slots.acquire(onEvicted: evictionOf('a'));
      slots.acquire(onEvicted: evictionOf('b'));
      slots.acquire(onEvicted: evictionOf('c'));

      slots.acquire(onEvicted: evictionOf('d'));
      slots.acquire(onEvicted: evictionOf('e'));

      expect(evicted, <String>['a', 'b']);
    });

    test('never evicts a pinned holder however stale it is', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 2);
      final VideoSlotToken? pinned =
          slots.acquire(onEvicted: evictionOf('pinned'));
      expect(pinned, isNotNull);
      slots.pin(pinned);
      slots.acquire(onEvicted: evictionOf('b'));

      expect(slots.acquire(onEvicted: evictionOf('c')), isNotNull);
      expect(evicted, <String>['b']);

      expect(slots.acquire(onEvicted: evictionOf('d')), isNotNull);
      expect(evicted, <String>['b', 'c']);
    });

    test('denies a slot at the cap when every holder is pinned', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 2);
      final VideoSlotToken? first = slots.acquire(onEvicted: evictionOf('a'));
      final VideoSlotToken? second = slots.acquire(onEvicted: evictionOf('b'));
      expect(first, isNotNull);
      expect(second, isNotNull);
      slots.pin(first);
      slots.pin(second);
      slots.addSlotFreedListener(freedListener('waiting'));

      expect(slots.acquire(onEvicted: evictionOf('c')), isNull);
      expect(evicted, isEmpty);
      expect(freed, isEmpty);
    });

    test('frees the slot and notifies listeners on release', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 1);
      final VideoSlotToken? first = slots.acquire(onEvicted: evictionOf('a'));
      expect(first, isNotNull);
      slots.pin(first);
      slots.addSlotFreedListener(freedListener('waiting'));
      expect(slots.acquire(onEvicted: evictionOf('denied')), isNull);

      slots.release(first);

      expect(freed, <String>['waiting']);
      expect(slots.acquire(onEvicted: evictionOf('retry')), isNotNull);
      expect(evicted, isEmpty);
    });

    test('treats a repeated or foreign release as a silent no-op', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 2);
      final LruVideoSlots other = LruVideoSlots(cap: 2);
      final VideoSlotToken? token = slots.acquire(onEvicted: evictionOf('a'));
      final VideoSlotToken? foreign =
          other.acquire(onEvicted: evictionOf('foreign'));
      expect(token, isNotNull);
      expect(foreign, isNotNull);
      slots.addSlotFreedListener(freedListener('waiting'));

      slots.release(token);
      expect(freed, <String>['waiting']);

      slots.release(token);
      slots.release(foreign);
      slots.release(null);

      expect(freed, <String>['waiting']);
      expect(evicted, isEmpty);
    });

    test('does not resurrect a released token through pin, touch or unpin', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 3);
      final VideoSlotToken? dead = slots.acquire(onEvicted: evictionOf('dead'));
      slots.acquire(onEvicted: evictionOf('b'));
      slots.acquire(onEvicted: evictionOf('c'));
      expect(dead, isNotNull);
      slots.release(dead);
      expect(slots.holds(dead), isFalse);

      slots.pin(dead);
      slots.touch(dead);
      slots.unpin(dead);

      expect(slots.holds(dead), isFalse);
      expect(slots.acquire(onEvicted: evictionOf('d')), isNotNull);
      expect(evicted, isEmpty);
      expect(slots.acquire(onEvicted: evictionOf('e')), isNotNull);
      expect(evicted, <String>['b']);
    });

    test('leaves a holder where it is in the eviction order when it pins', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 3);
      final VideoSlotToken? first = slots.acquire(onEvicted: evictionOf('a'));
      slots.acquire(onEvicted: evictionOf('b'));
      slots.acquire(onEvicted: evictionOf('c'));
      expect(first, isNotNull);

      slots.pin(first);
      slots.dispose();

      expect(evicted, <String>['a', 'b', 'c']);
    });

    test('refreshes recency when a holder unpins', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 3);
      final VideoSlotToken? first = slots.acquire(onEvicted: evictionOf('a'));
      slots.acquire(onEvicted: evictionOf('b'));
      slots.acquire(onEvicted: evictionOf('c'));
      expect(first, isNotNull);
      slots.pin(first);

      slots.unpin(first);

      expect(slots.acquire(onEvicted: evictionOf('d')), isNotNull);
      expect(evicted, <String>['b']);
      expect(slots.holds(first), isTrue);
    });

    test('spares a touched holder from being the next eviction victim', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 3);
      final VideoSlotToken? first = slots.acquire(onEvicted: evictionOf('a'));
      slots.acquire(onEvicted: evictionOf('b'));
      slots.acquire(onEvicted: evictionOf('c'));
      expect(first, isNotNull);

      slots.touch(first);

      expect(slots.acquire(onEvicted: evictionOf('d')), isNotNull);
      expect(evicted, <String>['b']);
    });

    test('stops notifying a slot freed listener once it is removed', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 2);
      final VideoSlotFreedListener removed = freedListener('removed');
      slots.addSlotFreedListener(removed);
      slots.addSlotFreedListener(freedListener('kept'));
      slots.removeSlotFreedListener(removed);
      final VideoSlotToken? token = slots.acquire(onEvicted: evictionOf('a'));
      expect(token, isNotNull);

      slots.release(token);

      expect(freed, <String>['kept']);
    });

    test('survives an evicted holder releasing its own token synchronously',
        () {
      final LruVideoSlots slots = LruVideoSlots(cap: 2);
      slots.addSlotFreedListener(freedListener('waiting'));
      VideoSlotToken? reentrant;
      reentrant = slots.acquire(onEvicted: () {
        evicted.add('reentrant');
        slots.release(reentrant);
      });
      expect(reentrant, isNotNull);
      expect(slots.acquire(onEvicted: evictionOf('b')), isNotNull);

      expect(slots.acquire(onEvicted: evictionOf('c')), isNotNull);

      expect(evicted, <String>['reentrant']);
      expect(freed, isEmpty);
      expect(slots.acquire(onEvicted: evictionOf('d')), isNotNull);
      expect(evicted, <String>['reentrant', 'b']);
    });

    test('coalesces slot freed notification when a listener releases in turn',
        () {
      final LruVideoSlots slots = LruVideoSlots(cap: 3);
      final VideoSlotToken? first = slots.acquire(onEvicted: evictionOf('a'));
      final VideoSlotToken? second = slots.acquire(onEvicted: evictionOf('b'));
      expect(first, isNotNull);
      expect(second, isNotNull);
      int depth = 0;
      int deepest = 0;
      slots.addSlotFreedListener(() {
        depth += 1;
        deepest = depth > deepest ? depth : deepest;
        freed.add('cascade');
        slots.release(second);
        depth -= 1;
      });
      slots.addSlotFreedListener(freedListener('observer'));

      slots.release(first);

      expect(deepest, 1);
      expect(freed, <String>['cascade', 'observer', 'cascade', 'observer']);
    });

    test('never evicts an in-flight grant from a reentrant acquire at cap one',
        () {
      final LruVideoSlots slots = LruVideoSlots(cap: 1);
      VideoSlotToken? inner;
      bool innerAttempted = false;
      slots.acquire(onEvicted: () {
        evicted.add('victim');
        innerAttempted = true;
        inner = slots.acquire(onEvicted: evictionOf('inner'));
      });

      final VideoSlotToken? outer = slots.acquire(onEvicted: evictionOf('outer'));

      expect(innerAttempted, isTrue);
      expect(inner, isNull);
      expect(outer, isNotNull);
      expect(evicted, <String>['victim']);
      expect(slots.holds(outer), isTrue);
    });

    test('spares an in-flight grant when a reentrant acquire has no other victim',
        () {
      final LruVideoSlots slots = LruVideoSlots(cap: 2);
      VideoSlotToken? inner;
      slots.acquire(onEvicted: () {
        evicted.add('victim');
        inner = slots.acquire(onEvicted: evictionOf('inner'));
      });
      final VideoSlotToken? pinned =
          slots.acquire(onEvicted: evictionOf('pinned'));
      expect(pinned, isNotNull);
      slots.pin(pinned);

      final VideoSlotToken? outer = slots.acquire(onEvicted: evictionOf('outer'));

      expect(inner, isNull);
      expect(outer, isNotNull);
      expect(evicted, <String>['victim']);
      expect(slots.holds(outer), isTrue);
      expect(slots.holds(pinned), isTrue);
    });

    test('lets a reentrant acquire evict a genuinely different holder', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 2);
      VideoSlotToken? inner;
      slots.acquire(onEvicted: () {
        evicted.add('victim');
        inner = slots.acquire(onEvicted: evictionOf('inner'));
      });
      final VideoSlotToken? survivor =
          slots.acquire(onEvicted: evictionOf('survivor'));
      expect(survivor, isNotNull);

      final VideoSlotToken? outer = slots.acquire(onEvicted: evictionOf('outer'));

      expect(outer, isNotNull);
      expect(inner, isNotNull);
      expect(evicted, <String>['victim', 'survivor']);
      expect(slots.holds(outer), isTrue);
      expect(slots.holds(inner), isTrue);
      expect(slots.holds(survivor), isFalse);
    });

    test('reports a throwing eviction callback and keeps granting', () {
      final List<Object> errors = <Object>[];
      final LruVideoSlots slots = LruVideoSlots(
        cap: 1,
        onCallbackError: (Object error, StackTrace stackTrace) =>
            errors.add(error),
      );
      slots.acquire(onEvicted: () => throw StateError('teardown failed'));

      expect(slots.acquire(onEvicted: evictionOf('b')), isNotNull);

      expect(errors, hasLength(1));
      expect(errors.single, isStateError);
      expect(slots.acquire(onEvicted: evictionOf('c')), isNotNull);
      expect(evicted, <String>['b']);
    });

    test('tears down every live holder and latches shut on dispose', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 3);
      slots.addSlotFreedListener(freedListener('waiting'));
      final VideoSlotToken? first = slots.acquire(onEvicted: evictionOf('a'));
      final VideoSlotToken? second = slots.acquire(onEvicted: evictionOf('b'));
      expect(first, isNotNull);
      expect(second, isNotNull);
      slots.pin(second);

      slots.dispose();

      expect(evicted, <String>['a', 'b']);
      expect(slots.holds(first), isFalse);
      expect(slots.holds(second), isFalse);
      expect(freed, isEmpty);
      expect(slots.acquire(onEvicted: evictionOf('c')), isNull);
    });

    test('ignores every mutator once disposed', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 2);
      final VideoSlotToken? first = slots.acquire(onEvicted: evictionOf('a'));
      expect(first, isNotNull);

      slots.dispose();
      expect(evicted, <String>['a']);

      slots.addSlotFreedListener(freedListener('late'));
      slots.release(first);
      slots.pin(first);
      slots.touch(first);
      slots.unpin(first);
      slots.dispose();

      expect(evicted, <String>['a']);
      expect(freed, isEmpty);
      expect(slots.holds(first), isFalse);
    });

    test('rejects a cap below one', () {
      expect(() => LruVideoSlots(cap: 0), throwsArgumentError);
      expect(() => LruVideoSlots(cap: -1), throwsArgumentError);
    });
  });

  group('UnlimitedVideoSlots', () {
    test('always grants and never evicts', () {
      const VideoSlots slots = UnlimitedVideoSlots();
      final List<VideoSlotToken> tokens = <VideoSlotToken>[];

      for (int index = 0;
          index < assumedConcurrentVideoDecoderCap * 3;
          index += 1) {
        final VideoSlotToken? token =
            slots.acquire(onEvicted: evictionOf('holder$index'));
        expect(token, isNotNull);
        tokens.add(token!);
      }

      expect(tokens.toSet(), hasLength(tokens.length));
      expect(evicted, isEmpty);
      expect(slots.holds(tokens.first), isTrue);
      expect(slots.holds(tokens.last), isTrue);
      expect(slots.holds(null), isFalse);
    });

    test('ignores release, pin, touch and listener calls', () {
      const VideoSlots slots = UnlimitedVideoSlots();
      final VideoSlotToken? token = slots.acquire(onEvicted: evictionOf('a'));
      expect(token, isNotNull);
      final VideoSlotFreedListener listener = freedListener('waiting');

      slots.addSlotFreedListener(listener);
      slots.pin(token);
      slots.touch(token);
      slots.unpin(token);
      slots.release(token);
      slots.release(token);
      slots.removeSlotFreedListener(listener);
      slots.dispose();

      expect(freed, isEmpty);
      expect(evicted, isEmpty);
    });
  });
}
