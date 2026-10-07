import 'dart:io';

import 'package:flutter/services.dart';

const String deviceStorageChannelName = 'field_notes/device_storage';
const String freeBytesMethod = 'freeBytes';
const int storageReserveBytes = 256 * 1024 * 1024;
const int noSpaceLeftErrorCode = 28;

class NotEnoughSpaceException implements Exception {
  const NotEnoughSpaceException({required this.needed, required this.free});

  final int needed;
  final int free;

  @override
  String toString() =>
      'NotEnoughSpaceException: needs $needed bytes, $free free';
}

bool isNoSpaceLeft(FileSystemException error) =>
    error.osError?.errorCode == noSpaceLeftErrorCode;

abstract interface class DeviceStorage {
  Future<int?> freeBytes(Directory near);
}

final class PlatformDeviceStorage implements DeviceStorage {
  const PlatformDeviceStorage([
    this._channel = const MethodChannel(deviceStorageChannelName),
  ]);

  final MethodChannel _channel;

  @override
  Future<int?> freeBytes(Directory near) async {
    try {
      return await _channel.invokeMethod<int>(
        freeBytesMethod,
        <String, Object?>{'path': near.path},
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

final class UnmeasuredDeviceStorage implements DeviceStorage {
  const UnmeasuredDeviceStorage();

  @override
  Future<int?> freeBytes(Directory near) async => null;
}

Future<void> requireSpace(
  DeviceStorage storage,
  Directory near,
  int bytes,
) async {
  final int? free = await storage.freeBytes(near);
  final int needed = bytes + storageReserveBytes;
  if (free != null && free < needed) {
    throw NotEnoughSpaceException(needed: needed, free: free);
  }
}
