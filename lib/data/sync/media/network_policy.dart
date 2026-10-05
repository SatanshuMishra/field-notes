import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum NetworkKind { offline, unmetered, metered }

enum TransferKind { record, poster, fullMedia }

abstract interface class NetworkMonitor {
  Future<NetworkKind> current();

  Stream<NetworkKind> get changes;
}

NetworkKind networkKindOf(
  List<ConnectivityResult> results, {
  required TargetPlatform platform,
}) {
  final List<ConnectivityResult> connected = <ConnectivityResult>[
    for (final ConnectivityResult result in results)
      if (result != ConnectivityResult.none) result,
  ];
  if (connected.isEmpty) {
    return NetworkKind.offline;
  }
  final bool unmeteredLink =
      connected.contains(ConnectivityResult.wifi) ||
      connected.contains(ConnectivityResult.ethernet);
  final bool meteredLink =
      connected.contains(ConnectivityResult.mobile) ||
      connected.contains(ConnectivityResult.satellite);
  if (platform == TargetPlatform.android && meteredLink && !unmeteredLink) {
    return NetworkKind.metered;
  }
  return NetworkKind.unmetered;
}

final class ConnectivityNetworkMonitor implements NetworkMonitor {
  ConnectivityNetworkMonitor({
    Connectivity? connectivity,
    TargetPlatform? platform,
  }) : _connectivity = connectivity ?? Connectivity(),
       _platform = platform ?? defaultTargetPlatform;

  final Connectivity _connectivity;
  final TargetPlatform _platform;

  @override
  Future<NetworkKind> current() async => networkKindOf(
    await _connectivity.checkConnectivity(),
    platform: _platform,
  );

  @override
  Stream<NetworkKind> get changes => _connectivity.onConnectivityChanged
      .map(
        (List<ConnectivityResult> results) =>
            networkKindOf(results, platform: _platform),
      )
      .distinct();
}

final class NetworkPolicy {
  const NetworkPolicy({required this.allowMobileDataForMedia});

  final bool allowMobileDataForMedia;

  bool allows(TransferKind kind, NetworkKind network) => switch (network) {
    NetworkKind.offline => false,
    NetworkKind.unmetered => true,
    NetworkKind.metered =>
      kind != TransferKind.fullMedia || allowMobileDataForMedia,
  };

  bool requiresWiFi(TransferKind kind) =>
      kind == TransferKind.fullMedia && !allowMobileDataForMedia;
}
