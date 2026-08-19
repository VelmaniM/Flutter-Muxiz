import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../app/constants.dart';

enum NetworkStatus {
  online,
  offline,
  reconnecting,
}

final networkStatusProvider = StateNotifierProvider<NetworkStatusNotifier, NetworkStatus>((ref) {
  return NetworkStatusNotifier();
});

class NetworkStatusNotifier extends StateNotifier<NetworkStatus> {
  Timer? _pollingTimer;
  final Dio _pingDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
    ),
  );

  NetworkStatusNotifier() : super(NetworkStatus.online) {
    _startNetworkMonitoring();
  }

  void _startNetworkMonitoring() {
    // Periodic lightweight reachability check every 15 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) => checkConnectivity());
  }

  Future<bool> checkConnectivity() async {
    try {
      final response = await _pingDio.get(
        '${AppConstants.defaultApiBaseUrl}/songs?limit=1',
      );
      final isSuccess = response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 400;
      if (isSuccess && state != NetworkStatus.online) {
        state = NetworkStatus.online;
      }
      return isSuccess;
    } catch (_) {
      if (state == NetworkStatus.online) {
        state = NetworkStatus.offline;
      }
      return false;
    }
  }

  void setStatus(NetworkStatus newStatus) {
    if (state != newStatus) {
      state = newStatus;
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
