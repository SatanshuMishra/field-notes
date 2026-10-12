import 'package:field_notes/design/feedback/toast.dart';
import 'package:field_notes/features/updates/update_controller.dart';
import 'package:field_notes/features/updates/update_wording.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UpdateGreeting extends ConsumerStatefulWidget {
  const UpdateGreeting({super.key});

  @override
  ConsumerState<UpdateGreeting> createState() => _UpdateGreetingState();
}

class _UpdateGreetingState extends ConsumerState<UpdateGreeting> {
  @override
  void initState() {
    super.initState();
    ref.listenManual<String?>(
      updateGreetingProvider,
      _onGreeting,
      fireImmediately: true,
    );
  }

  void _onGreeting(String? previous, String? version) {
    if (version == null) {
      return;
    }
    WidgetsBinding.instance
      ..addPostFrameCallback((Duration _) => _greet())
      ..ensureVisualUpdate();
  }

  void _greet() {
    if (!mounted) {
      return;
    }
    final String? version = ref.read(updateGreetingProvider);
    if (version == null) {
      return;
    }
    ref.read(updateGreetingProvider.notifier).consume();
    showTransientToast(context, updatedGreeting(version));
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
