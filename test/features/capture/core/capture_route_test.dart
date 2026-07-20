import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_route.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

CaptureRoute _routeReturning(EntryType type, String entryId) {
  return CaptureRoute(
    type: type,
    open: (BuildContext context, String date) async => entryId,
  );
}

void main() {
  group('captureOptions', () {
    test('offers the three spec options in capture order', () {
      expect(
        captureOptions.map((CaptureOption option) => option.type),
        <EntryType>[EntryType.text, EntryType.voice, EntryType.video],
      );
      expect(
        captureOptions.map((CaptureOption option) => option.label),
        <String>['Write a note', 'Record voice', 'Record video'],
      );
    });
  });

  group('CaptureRouteRegistry', () {
    test('supports nothing when empty', () {
      expect(CaptureRouteRegistry.empty.supports(EntryType.text), isFalse);
      expect(CaptureRouteRegistry.empty.routeFor(EntryType.text), isNull);
    });

    test('withRoute returns a new registry and leaves the original alone', () {
      const CaptureRouteRegistry base = CaptureRouteRegistry.empty;

      final CaptureRouteRegistry withText =
          base.withRoute(_routeReturning(EntryType.text, 'entry-1'));

      expect(withText.supports(EntryType.text), isTrue);
      expect(base.supports(EntryType.text), isFalse);
      expect(identical(withText, base), isFalse);
    });

    test('withRoute replaces a route of the same type instead of duplicating',
        () async {
      final CaptureRouteRegistry registry = CaptureRouteRegistry.empty
          .withRoute(_routeReturning(EntryType.text, 'first'))
          .withRoute(_routeReturning(EntryType.text, 'second'));

      expect(registry.routes, hasLength(1));
      expect(
        await registry
            .routeFor(EntryType.text)!
            .open(_FakeContext(), '2026-07-19'),
        'second',
      );
    });

    test('exposes an unmodifiable route list', () {
      final CaptureRouteRegistry registry = CaptureRouteRegistry.empty
          .withRoute(_routeReturning(EntryType.text, 'entry-1'));

      expect(
        () => registry.routes.add(_routeReturning(EntryType.voice, 'entry-2')),
        throwsUnsupportedError,
      );
    });
  });
}

class _FakeContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
