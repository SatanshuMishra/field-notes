import 'states/viewer_states.dart';
import 'support/a11y_state.dart';

void main() {
  a11ySweepArea(
    area: 'viewer',
    groupName: 'every viewer state loads and matches its baseline',
    states: viewerStates,
  );
}
