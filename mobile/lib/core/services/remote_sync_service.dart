import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/constants.dart';
import '../data/mock_catalog.dart';
import '../storage/local_storage.dart';

final remoteSyncServiceProvider = Provider<RemoteSyncService>((ref) {
  return RemoteSyncService.instance;
});

class RemoteSyncService {
  static final RemoteSyncService instance = RemoteSyncService._internal();
  RemoteSyncService._internal();

  Timer? _pollTimer;
  int _lastKnownEpoch = 0;
  bool _isListening = false;
  CancelToken? _cancelToken;

  /// Starts real-time SSE listener and background epoch watcher
  void start() {
    if (_isListening) return;
    _isListening = true;
    _startSSEListener();
    _startEpochPolling();
  }

  void stop() {
    _isListening = false;
    _cancelToken?.cancel();
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _startEpochPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      checkEpochAndWipeIfNeeded();
    });
  }

  /// Connects to real-time SSE stream from Muxiz Studio Server
  Future<void> _startSSEListener() async {
    while (_isListening) {
      final urls = [AppConstants.defaultApiBaseUrl, ...AppConstants.fallbackApiBaseUrls];
      bool connected = false;

      for (final base in urls) {
        if (!_isListening) break;
        try {
          _cancelToken = CancelToken();
          final dio = Dio(
            BaseOptions(
              responseType: ResponseType.stream,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(minutes: 30),
            ),
          );

          final endpoint = '$base/server/events';
          final response = await dio.get<ResponseBody>(
            endpoint,
            cancelToken: _cancelToken,
          );

          if (response.statusCode == 200 && response.data != null) {
            connected = true;
            final stream = response.data!.stream;
            String buffer = '';

            await for (final chunk in stream) {
              if (!_isListening) break;
              final text = utf8.decode(chunk);
              buffer += text;

              while (buffer.contains('\n\n')) {
                final idx = buffer.indexOf('\n\n');
                final message = buffer.substring(0, idx);
                buffer = buffer.substring(idx + 2);

                _handleSSEMessage(message);
              }
            }
          }
        } catch (_) {
          // Try next url
        }
      }

      if (!connected && _isListening) {
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }

  void _handleSSEMessage(String rawMessage) {
    try {
      final lines = rawMessage.split('\n');
      String? eventName;

      for (final line in lines) {
        if (line.startsWith('event:')) {
          eventName = line.substring(6).trim();
        }
      }

      if (eventName == 'app_cache_wipe') {
        debugPrint('🧹 [RemoteSync] Received instant remote app cache wipe signal from Studio!');
        executeInstantRemoteCacheWipe();
      } else if (eventName == 'catalog_update') {
        debugPrint('🔄 [RemoteSync] Received catalog update signal from Studio.');
        MockMusicCatalog.initializeCatalog(background: true);
      }
    } catch (_) {}
  }

  /// Checks if Studio has broadcasted a newer cache wipe epoch
  Future<void> checkEpochAndWipeIfNeeded() async {
    final urls = [AppConstants.defaultApiBaseUrl, ...AppConstants.fallbackApiBaseUrls];
    for (final base in urls) {
      try {
        final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 3)));
        final res = await dio.get('$base/cache/epoch');
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data;
          final int serverEpoch = (data['epoch'] ?? data['lastWipeEpoch'] ?? 0) as int;

          if (_lastKnownEpoch == 0) {
            _lastKnownEpoch = serverEpoch;
            return;
          }

          if (serverEpoch > _lastKnownEpoch) {
            _lastKnownEpoch = serverEpoch;
            debugPrint('🧹 [RemoteSync] Newer cache epoch detected ($serverEpoch > $_lastKnownEpoch). Wiping app cache...');
            await executeInstantRemoteCacheWipe();
          }
          break;
        }
      } catch (_) {}
    }
  }

  /// Executes immediate app cache & local storage clearance
  Future<void> executeInstantRemoteCacheWipe() async {
    try {
      // 1. Clear Flutter Image In-Memory & Live Cache
      try {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      } catch (_) {}

      // 2. Clear LocalStorage and temporary playback files
      await LocalStorageService.clearAllPlaybackAndCache();

      // 3. Re-initialize and download fresh catalog from Studio
      await MockMusicCatalog.initializeCatalog(background: true);

      // 4. Notify all Riverpod listeners across Home, Search & Player screens
      catalogNotifier.notify();

      debugPrint('✅ [RemoteSync] Instant remote app cache and local storage wipe completed successfully!');
    } catch (e) {
      debugPrint('⚠️ [RemoteSync] Error executing cache wipe: $e');
    }
  }
}
