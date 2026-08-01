import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shell_navigation.g.dart';

@Riverpod(keepAlive: true)
class ShellNavigation extends _$ShellNavigation {
  @override
  ShellDestination build() => ShellDestination.today;

  void select(ShellDestination destination) => state = destination;
}
