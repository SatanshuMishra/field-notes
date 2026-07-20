import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/chooser/capture_routes_provider.dart';
import 'package:field_notes/features/capture/core/capture_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('captureRoutesProvider registers the text capture route only', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final CaptureRouteRegistry registry = container.read(captureRoutesProvider);

    expect(registry.supports(EntryType.text), isTrue);
    expect(registry.supports(EntryType.voice), isFalse);
    expect(registry.supports(EntryType.video), isFalse);
  });
}
