import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_route.dart';

class AudioRouteState {
  final AudioRoute? currentRoute;
  final List<AudioRoute> availableRoutes;
  final bool isLoading;
  final String? errorMessage;

  const AudioRouteState({
    this.currentRoute,
    this.availableRoutes = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  AudioRouteState copyWith({
    AudioRoute? currentRoute,
    List<AudioRoute>? availableRoutes,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AudioRouteState(
      currentRoute: currentRoute ?? this.currentRoute,
      availableRoutes: availableRoutes ?? this.availableRoutes,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final audioRouteProvider = StateNotifierProvider<AudioRouteNotifier, AudioRouteState>((ref) {
  return AudioRouteNotifier();
});

class AudioRouteNotifier extends StateNotifier<AudioRouteState> {
  static const MethodChannel _channel = MethodChannel('com.muxiz.app/audio_route');

  AudioRouteNotifier() : super(const AudioRouteState(isLoading: true)) {
    _initChannel();
    refreshRoutes();
  }

  void _initChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onRouteChange') {
        final data = call.arguments;
        if (data is Map) {
          _handleRouteChanged(data);
        } else {
          await refreshRoutes();
        }
      }
    });
  }

  void _handleRouteChanged(Map<dynamic, dynamic> data) {
    try {
      final currentMap = data['currentRoute'] as Map<dynamic, dynamic>?;
      final listRaw = data['availableRoutes'] as List<dynamic>? ?? [];

      final current = currentMap != null ? AudioRoute.fromMap(currentMap) : null;
      final available = listRaw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => AudioRoute.fromMap(m))
          .toList();

      state = state.copyWith(
        currentRoute: current,
        availableRoutes: available.isNotEmpty ? available : state.availableRoutes,
        isLoading: false,
        clearError: true,
      );
    } catch (_) {
      refreshRoutes();
    }
  }

  Future<void> refreshRoutes() async {
    try {
      state = state.copyWith(isLoading: true);
      final dynamic result = await _channel.invokeMethod('getAvailableRoutes');

      if (result is Map) {
        final currentMap = result['currentRoute'] as Map<dynamic, dynamic>?;
        final listRaw = result['availableRoutes'] as List<dynamic>? ?? [];

        final current = currentMap != null ? AudioRoute.fromMap(currentMap) : null;
        final available = listRaw
            .whereType<Map<dynamic, dynamic>>()
            .map((m) => AudioRoute.fromMap(m))
            .toList();

        state = state.copyWith(
          currentRoute: current ?? _defaultSpeakerRoute(),
          availableRoutes: available.isNotEmpty ? available : [_defaultSpeakerRoute()],
          isLoading: false,
          clearError: true,
        );
      } else {
        // Fallback default
        final defaultRoute = _defaultSpeakerRoute();
        state = state.copyWith(
          currentRoute: defaultRoute,
          availableRoutes: [defaultRoute],
          isLoading: false,
        );
      }
    } catch (e) {
      final defaultRoute = _defaultSpeakerRoute();
      state = state.copyWith(
        currentRoute: state.currentRoute ?? defaultRoute,
        availableRoutes: state.availableRoutes.isNotEmpty ? state.availableRoutes : [defaultRoute],
        isLoading: false,
        errorMessage: 'Route query error: $e',
      );
    }
  }

  Future<bool> selectRoute(AudioRoute targetRoute) async {
    try {
      state = state.copyWith(
        currentRoute: targetRoute.copyWith(isSelected: true),
        availableRoutes: state.availableRoutes.map((r) {
          return r.copyWith(isSelected: r.id == targetRoute.id);
        }).toList(),
      );

      final bool success = await _channel.invokeMethod('selectRoute', {
        'id': targetRoute.id,
        'type': targetRoute.type.name,
      }) ?? true;

      // Refresh to confirm OS updated route
      await Future.delayed(const Duration(milliseconds: 200));
      await refreshRoutes();
      return success;
    } catch (e) {
      debugPrint('Error selecting audio route: $e');
      await refreshRoutes();
      return false;
    }
  }

  Future<void> showSystemRoutePicker() async {
    try {
      await _channel.invokeMethod('showSystemRoutePicker');
    } catch (e) {
      debugPrint('Error showing system route picker: $e');
    }
  }

  AudioRoute _defaultSpeakerRoute() {
    return const AudioRoute(
      id: 'speaker',
      name: 'iPhone Speaker',
      type: AudioRouteType.speaker,
      isSelected: true,
      isAvailable: true,
    );
  }
}
