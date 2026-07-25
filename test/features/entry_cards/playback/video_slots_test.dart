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

  VideoSlotToken? evicting(VideoSlots slots, String name) => slots.acquire(
        onEvicted: evictionOf(name),
        evictionRights: VideoSlotEvictionRights.evictUnpinned,
      );

  VideoSlotToken? passive(VideoSlots slots, String name) => slots.acquire(
        onEvicted: evictionOf(name),
        evictionRights: VideoSlotEvictionRights.none,
      );

  group('LruVideoSlots', () {
    test('grants a slot while the registry is under the cap', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 2);

      final VideoSlotToken? first = evicting(slots, 'a');
      final VideoSlotToken? second = evicting(slots, 'b');

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
          evicting(slots, 'holder$index'),
          isNotNull,
        );
      }
      expect(evicted, isEmpty);

      expect(evicting(slots, 'overflow'), isNotNull);
      expect(evicted, <String>['holder0']);
    });

    test('reports whether a token still holds a slot', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 1);
      final LruVideoSlots other = LruVideoSlots(cap: 1);
      final VideoSlotToken? token = evicting(slots, 'a');
      final VideoSlotToken? foreign =
          evicting(other, 'foreign');
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
      final VideoSlotToken? first = evicting(slots, 'a');
      final VideoSlotToken? second = evicting(slots, 'b');

      final VideoSlotToken? third = evicting(slots, 'c');

      expect(third, isNotNull);
      expect(evicted, <String>['a']);
      expect(slots.holds(first), isFalse);
      expect(slots.holds(second), isTrue);
      expect(slots.holds(third), isTrue);
    });

    test('notifies only the evicted holder and only once', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 3);
      evicting(slots, 'a');
      evicting(slots, 'b');
      evicting(slots, 'c');

      evicting(slots, 'd');
      evicting(slots, 'e');

      expect(evicted, <String>['a', 'b']);
    });

    test('never evicts a pinned holder however stale it is', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 2);
      final VideoSlotToken? pinned =
          evicting(slots, 'pinned');
      expect(pinned, isNotNull);
      slots.pin(pinned);
      evicting(slots, 'b');

      expect(evicting(slots, 'c'), isNotNull);
      expect(evicted, <String>['b']);

      expect(evicting(slots, 'd'), isNotNull);
      expect(evicted, <String>['b', 'c']);
    });

    test('denies a slot at the cap when every holder is pinned', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 2);
      final VideoSlotToken? first = evicting(slots, 'a');
      final VideoSlotToken? second = evicting(slots, 'b');
      expect(first, isNotNull);
      expect(second, isNotNull);
      slots.pin(first);
      slots.pin(second);
      slots.addSlotFreedListener(freedListener('waiting'));

      expect(evicting(slots, 'c'), isNull);
      expect(evicted, isEmpty);
      expect(freed, isEmpty);
    });

    test('grants under the cap without eviction rights', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 2);
      final VideoSlotToken? first = passive(slots, 'a');
      final VideoSlotToken? second = passive(slots, 'b');

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(slots.holds(first), isTrue);
      expect(slots.holds(second), isTrue);
      expect(evicted, isEmpty);
    });

    test('denies at the cap without eviction rights and evicts nothing', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 2);
      final VideoSlotToken? first = passive(slots, 'a');
      final VideoSlotToken? second = passive(slots, 'b');
      expect(first, isNotNull);
      expect(second, isNotNull);
      slots.addSlotFreedListener(freedListener('waiting'));

      expect(passive(slots, 'c'), isNull);
      expect(passive(slots, 'd'), isNull);

      expect(evicted, isEmpty);
      expect(freed, isEmpty);
      expect(slots.holds(first), isTrue);
      expect(slots.holds(second), isTrue);
    });

    test('evicts for the same registry state once eviction rights are given',
        () {
      final LruVideoSlots slots = LruVideoSlots(cap: 2);
      final VideoSlotToken? first = passive(slots, 'a');
      final VideoSlotToken? second = passive(slots, 'b');
      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(passive(slots, 'denied'), isNull);
      expect(evicted, isEmpty);

      final VideoSlotToken? claimed = evicting(slots, 'claimed');

      expect(claimed, isNotNull);
      expect(evicted, <String>['a']);
      expect(slots.holds(first), isFalse);
      expect(slots.holds(second), isTrue);
      expect(slots.holds(claimed), isTrue);
    });

    test('reports whether a slot freed listener could be registered', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 1);
      final VideoSlotFreedListener listener = freedListener('waiting');

      expect(slots.addSlotFreedListener(listener), isTrue);
      expect(slots.addSlotFreedListener(listener), isTrue);

      slots.dispose();

      expect(slots.addSlotFreedListener(freedListener('late')), isFalse);
      expect(passive(slots, 'late'), isNull);
      expect(evicting(slots, 'late'), isNull);
    });

    test('frees the slot and notifies listeners on release', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 1);
      final VideoSlotToken? first = evicting(slots, 'a');
      expect(first, isNotNull);
      slots.pin(first);
      slots.addSlotFreedListener(freedListener('waiting'));
      expect(evicting(slots, 'denied'), isNull);

      slots.release(first);

      expect(freed, <String>['waiting']);
      expect(evicting(slots, 'retry'), isNotNull);
      expect(evicted, isEmpty);
    });

    test('treats a repeated or foreign release as a silent no-op', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 2);
      final LruVideoSlots other = LruVideoSlots(cap: 2);
      final VideoSlotToken? token = evicting(slots, 'a');
      final VideoSlotToken? foreign =
          evicting(other, 'foreign');
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
      final VideoSlotToken? dead = evicting(slots, 'dead');
      evicting(slots, 'b');
      evicting(slots, 'c');
      expect(dead, isNotNull);
      slots.release(dead);
      expect(slots.holds(dead), isFalse);

      slots.pin(dead);
      slots.touch(dead);
      slots.unpin(dead);

      expect(slots.holds(dead), isFalse);
      expect(evicting(slots, 'd'), isNotNull);
      expect(evicted, isEmpty);
      expect(evicting(slots, 'e'), isNotNull);
      expect(evicted, <String>['b']);
    });

    test('leaves a holder where it is in the eviction order when it pins', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 3);
      final VideoSlotToken? first = evicting(slots, 'a');
      evicting(slots, 'b');
      evicting(slots, 'c');
      expect(first, isNotNull);

      slots.pin(first);
      slots.dispose();

      expect(evicted, <String>['a', 'b', 'c']);
    });

    test('refreshes recency when a holder unpins', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 3);
      final VideoSlotToken? first = evicting(slots, 'a');
      evicting(slots, 'b');
      evicting(slots, 'c');
      expect(first, isNotNull);
      slots.pin(first);

      slots.unpin(first);

      expect(evicting(slots, 'd'), isNotNull);
      expect(evicted, <String>['b']);
      expect(slots.holds(first), isTrue);
    });

    test('spares a touched holder from being the next eviction victim', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 3);
      final VideoSlotToken? first = evicting(slots, 'a');
      evicting(slots, 'b');
      evicting(slots, 'c');
      expect(first, isNotNull);

      slots.touch(first);

      expect(evicting(slots, 'd'), isNotNull);
      expect(evicted, <String>['b']);
    });

    test('stops notifying a slot freed listener once it is removed', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 2);
      final VideoSlotFreedListener removed = freedListener('removed');
      slots.addSlotFreedListener(removed);
      slots.addSlotFreedListener(freedListener('kept'));
      slots.removeSlotFreedListener(removed);
      final VideoSlotToken? token = evicting(slots, 'a');
      expect(token, isNotNull);

      slots.release(token);

      expect(freed, <String>['kept']);
    });

    test('survives an evicted holder releasing its own token synchronously',
        () {
      final LruVideoSlots slots = LruVideoSlots(cap: 2);
      slots.addSlotFreedListener(freedListener('waiting'));
      VideoSlotToken? reentrant;
      reentrant = slots.acquire(
        onEvicted: () {
          evicted.add('reentrant');
          slots.release(reentrant);
        },
        evictionRights: VideoSlotEvictionRights.evictUnpinned,
      );
      expect(reentrant, isNotNull);
      expect(evicting(slots, 'b'), isNotNull);

      expect(evicting(slots, 'c'), isNotNull);

      expect(evicted, <String>['reentrant']);
      expect(freed, isEmpty);
      expect(evicting(slots, 'd'), isNotNull);
      expect(evicted, <String>['reentrant', 'b']);
    });

    test('coalesces slot freed notification when a listener releases in turn',
        () {
      final LruVideoSlots slots = LruVideoSlots(cap: 3);
      final VideoSlotToken? first = evicting(slots, 'a');
      final VideoSlotToken? second = evicting(slots, 'b');
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
      slots.acquire(
        onEvicted: () {
          evicted.add('victim');
          innerAttempted = true;
          inner = evicting(slots, 'inner');
        },
        evictionRights: VideoSlotEvictionRights.evictUnpinned,
      );

      final VideoSlotToken? outer = evicting(slots, 'outer');

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
      slots.acquire(
        onEvicted: () {
          evicted.add('victim');
          inner = evicting(slots, 'inner');
        },
        evictionRights: VideoSlotEvictionRights.evictUnpinned,
      );
      final VideoSlotToken? pinned =
          evicting(slots, 'pinned');
      expect(pinned, isNotNull);
      slots.pin(pinned);

      final VideoSlotToken? outer = evicting(slots, 'outer');

      expect(inner, isNull);
      expect(outer, isNotNull);
      expect(evicted, <String>['victim']);
      expect(slots.holds(outer), isTrue);
      expect(slots.holds(pinned), isTrue);
    });

    test('lets a reentrant acquire evict a genuinely different holder', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 2);
      VideoSlotToken? inner;
      slots.acquire(
        onEvicted: () {
          evicted.add('victim');
          inner = evicting(slots, 'inner');
        },
        evictionRights: VideoSlotEvictionRights.evictUnpinned,
      );
      final VideoSlotToken? survivor =
          evicting(slots, 'survivor');
      expect(survivor, isNotNull);

      final VideoSlotToken? outer = evicting(slots, 'outer');

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
      slots.acquire(
        onEvicted: () => throw StateError('teardown failed'),
        evictionRights: VideoSlotEvictionRights.evictUnpinned,
      );

      expect(evicting(slots, 'b'), isNotNull);

      expect(errors, hasLength(1));
      expect(errors.single, isStateError);
      expect(evicting(slots, 'c'), isNotNull);
      expect(evicted, <String>['b']);
    });

    test('tears down every live holder and latches shut on dispose', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 3);
      slots.addSlotFreedListener(freedListener('waiting'));
      final VideoSlotToken? first = evicting(slots, 'a');
      final VideoSlotToken? second = evicting(slots, 'b');
      expect(first, isNotNull);
      expect(second, isNotNull);
      slots.pin(second);

      slots.dispose();

      expect(evicted, <String>['a', 'b']);
      expect(slots.holds(first), isFalse);
      expect(slots.holds(second), isFalse);
      expect(freed, isEmpty);
      expect(evicting(slots, 'c'), isNull);
    });

    test('ignores every mutator once disposed', () {
      final LruVideoSlots slots = LruVideoSlots(cap: 2);
      final VideoSlotToken? first = evicting(slots, 'a');
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
            evicting(slots, 'holder$index');
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
      final VideoSlotToken? token = evicting(slots, 'a');
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
