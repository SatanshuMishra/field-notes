import 'states/media_states.dart';
import 'support/a11y_state.dart';

void main() {
  a11ySweepArea(
    area: 'media',
    groupName: 'every media state loads and matches its baseline',
    states: mediaStates,
  );
}
