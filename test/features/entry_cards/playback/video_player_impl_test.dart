import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/entry_cards/playback/video_playback.dart';
import 'package:field_notes/features/entry_cards/playback/video_player_impl.dart';

typedef _Case = ({
  String name,
  bool hasError,
  bool isInitialized,
  bool isCompleted,
  bool isPlaying,
  VideoPlaybackState current,
  VideoPlaybackState expected,
});

void main() {
  group('videoStateFromValue', () {
    const List<_Case> cases = <_Case>[
      (
        name: 'maps a finished video to completed rather than paused',
        hasError: false,
        isInitialized: true,
        isCompleted: true,
        isPlaying: false,
        current: VideoPlaybackState.playing,
        expected: VideoPlaybackState.completed,
      ),
      (
        name: 'maps a seek to the end during playback to playing',
        hasError: false,
        isInitialized: true,
        isCompleted: true,
        isPlaying: true,
        current: VideoPlaybackState.playing,
        expected: VideoPlaybackState.playing,
      ),
      (
        name: 'maps a seek to the end while paused to completed',
        hasError: false,
        isInitialized: true,
        isCompleted: true,
        isPlaying: false,
        current: VideoPlaybackState.paused,
        expected: VideoPlaybackState.completed,
      ),
      (
        name: 'maps an error over a completed video',
        hasError: true,
        isInitialized: true,
        isCompleted: true,
        isPlaying: false,
        current: VideoPlaybackState.completed,
        expected: VideoPlaybackState.error,
      ),
      (
        name: 'maps an error over a playing video',
        hasError: true,
        isInitialized: true,
        isCompleted: false,
        isPlaying: true,
        current: VideoPlaybackState.playing,
        expected: VideoPlaybackState.error,
      ),
      (
        name: 'maps an error raised before initialization',
        hasError: true,
        isInitialized: false,
        isCompleted: false,
        isPlaying: false,
        current: VideoPlaybackState.loading,
        expected: VideoPlaybackState.error,
      ),
      (
        name: 'leaves loading untouched until the controller initializes',
        hasError: false,
        isInitialized: false,
        isCompleted: false,
        isPlaying: false,
        current: VideoPlaybackState.loading,
        expected: VideoPlaybackState.loading,
      ),
      (
        name: 'leaves idle untouched until the controller initializes',
        hasError: false,
        isInitialized: false,
        isCompleted: false,
        isPlaying: true,
        current: VideoPlaybackState.idle,
        expected: VideoPlaybackState.idle,
      ),
      (
        name: 'maps an initialized playing video to playing',
        hasError: false,
        isInitialized: true,
        isCompleted: false,
        isPlaying: true,
        current: VideoPlaybackState.ready,
        expected: VideoPlaybackState.playing,
      ),
      (
        name: 'maps an initialized idle video to paused',
        hasError: false,
        isInitialized: true,
        isCompleted: false,
        isPlaying: false,
        current: VideoPlaybackState.playing,
        expected: VideoPlaybackState.paused,
      ),
      (
        name: 'maps a replay after completion back to playing',
        hasError: false,
        isInitialized: true,
        isCompleted: false,
        isPlaying: true,
        current: VideoPlaybackState.completed,
        expected: VideoPlaybackState.playing,
      ),
      (
        name: 'maps a seek away from the end back to paused',
        hasError: false,
        isInitialized: true,
        isCompleted: false,
        isPlaying: false,
        current: VideoPlaybackState.completed,
        expected: VideoPlaybackState.paused,
      ),
    ];

    for (final _Case testCase in cases) {
      test(testCase.name, () {
        expect(
          videoStateFromValue(
            hasError: testCase.hasError,
            isInitialized: testCase.isInitialized,
            isCompleted: testCase.isCompleted,
            isPlaying: testCase.isPlaying,
            current: testCase.current,
          ),
          testCase.expected,
        );
      });
    }
  });
}
