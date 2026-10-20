class CameraMacOSMovieStart {
  const CameraMacOSMovieStart({
    this.firstFrameAge = Duration.zero,
    this.firstFrameCapturedAtNs,
  });

  factory CameraMacOSMovieStart.fromArguments(Object? arguments) {
    final Object? ageMs =
        arguments is Map ? arguments['firstFrameAgeMs'] : null;
    final Object? capturedAtNs =
        arguments is Map ? arguments['firstFrameCapturedAtNs'] : null;
    return CameraMacOSMovieStart(
      firstFrameAge: ageMs is num
          ? Duration(microseconds: (ageMs * 1000).round())
          : Duration.zero,
      firstFrameCapturedAtNs: capturedAtNs is int ? capturedAtNs : null,
    );
  }

  final Duration firstFrameAge;
  final int? firstFrameCapturedAtNs;
}
