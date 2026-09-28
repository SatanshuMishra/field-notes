import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shell_navigation.g.dart';

@Riverpod(keepAlive: true)
class ShellNavigation extends _$ShellNavigation {
  ShellDestination _settingsOrigin = ShellDestination.today;

  @override
  ShellDestination build() => ShellDestination.today;

  void select(ShellDestination destination) {
    if (destination == ShellDestination.settings &&
        state != ShellDestination.settings) {
      _settingsOrigin = state;
    }
    state = destination;
  }

  void back() => state = state == ShellDestination.settings
      ? _settingsOrigin
      : ShellDestination.today;
}
