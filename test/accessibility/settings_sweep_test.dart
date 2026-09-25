import 'states/settings_states.dart';
import 'support/a11y_state.dart';

void main() {
  a11ySweepArea(
    area: 'settings',
    groupName: 'every settings state loads and matches its baseline',
    states: settingsStates,
  );
}
