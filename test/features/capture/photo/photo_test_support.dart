import 'dart:convert';
import 'dart:typed_data';

import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/photo/photo_picker.dart';
import 'package:flutter/material.dart';

final Uint8List tinyPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

Widget photoHarness(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: child)),
  );
}

class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker({
    this.supportsCamera = true,
    this.libraryResult = const <CaptureMedia>[],
    this.cameraResult,
    this.libraryError,
    this.cameraError,
  });

  @override
  final bool supportsCamera;

  final List<CaptureMedia> libraryResult;
  final CaptureMedia? cameraResult;
  final PhotoPickException? libraryError;
  final PhotoPickException? cameraError;

  int libraryCalls = 0;
  int cameraCalls = 0;

  @override
  Future<List<CaptureMedia>> pickFromLibrary() async {
    libraryCalls++;
    final PhotoPickException? error = libraryError;
    if (error != null) {
      throw error;
    }
    return libraryResult;
  }

  @override
  Future<CaptureMedia?> captureFromCamera() async {
    cameraCalls++;
    final PhotoPickException? error = cameraError;
    if (error != null) {
      throw error;
    }
    return cameraResult;
  }
}
