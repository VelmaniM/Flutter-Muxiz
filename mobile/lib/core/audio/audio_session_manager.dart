import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';

enum AudioDeviceType {
  speaker,
  bluetooth,
  headphones,
  airplay,
}

class AudioSessionManager {
  AudioSession? _session;
  StreamSubscription? _interruptionSub;
  StreamSubscription? _noisySub;

  Function()? onPauseRequested;
  Function()? onResumeRequested;
  Function(double volume)? onDuckVolumeRequested;

  Future<void> initialize() async {
    try {
      _session = await AudioSession.instance;

      // Production-grade AudioSession configuration for continuous background playback
      await _session!.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ),
      );

      // 1. Interruption Handling (Phone calls, Siri, Alarms, system announcements)
      _interruptionSub = _session!.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              onDuckVolumeRequested?.call(0.3);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              onPauseRequested?.call();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              onDuckVolumeRequested?.call(1.0);
              break;
            case AudioInterruptionType.pause:
              onResumeRequested?.call();
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });

      // 2. Becoming Noisy (Headphones or Bluetooth unplugs -> Auto-continue on phone speaker)
      _noisySub = _session!.becomingNoisyEventStream.listen((_) async {
        debugPrint('Bluetooth / Headphones disconnected -> Automatically switching to phone speaker and continuing playback.');
        try {
          await routeAudioOutput(AudioDeviceType.speaker);
          await Future.delayed(const Duration(milliseconds: 150));
          onResumeRequested?.call();
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('AudioSession initialization error: $e');
    }
  }

  Future<void> activate() async {
    try {
      _session ??= await AudioSession.instance;
      await _session?.setActive(true);
    } catch (_) {}
  }

  /// Switch audio output route between built-in phone speaker and Bluetooth / AirPods
  Future<void> routeAudioOutput(AudioDeviceType targetType) async {
    try {
      if (Platform.isIOS) {
        final darwin = AVAudioSession();
        if (targetType == AudioDeviceType.speaker) {
          await darwin.overrideOutputAudioPort(AVAudioSessionPortOverride.speaker);
        } else {
          await darwin.overrideOutputAudioPort(AVAudioSessionPortOverride.none);
        }
      } else if (Platform.isAndroid) {
        final android = AndroidAudioManager();
        if (targetType == AudioDeviceType.speaker) {
          await android.setSpeakerphoneOn(true);
        } else {
          await android.setSpeakerphoneOn(false);
        }
      }
    } catch (e) {
      debugPrint('Audio routing error: $e');
    }
  }

  void dispose() {
    _interruptionSub?.cancel();
    _noisySub?.cancel();
  }
}
