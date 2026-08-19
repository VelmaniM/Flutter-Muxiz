import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'app/theme.dart';
import 'core/audio/audio_manager.dart';
import 'core/data/mock_catalog.dart';
import 'core/storage/local_storage.dart';
import 'features/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global exception shields to prevent app from closing/crashing
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Handled UI Error: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Handled Async Error: $error');
    return true; // Handled safely without terminating process
  };

  // Lock app orientation to Portrait Mode only (no rotation, Spotify/Apple Music style)
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  } catch (_) {}

  // Set system bar styles for full-bleed dark theme
  try {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF121212),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  } catch (_) {}

  // Initialize local storage safely
  try {
    await LocalStorageService.init();
  } catch (_) {}

  // Check if this is the 1st time or 2nd time onwards
  final bool isFirstTime = !LocalStorageService.hasSeenSplash();
  if (isFirstTime) {
    LocalStorageService.markSplashSeen();
  }

  // Initialize background AudioService safely with timeout fallback
  MuxizAudioHandler audioHandler;
  try {
    audioHandler = await AudioService.init(
      builder: () => MuxizAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.muxiz.app.audio',
        androidNotificationChannelName: 'Muxiz Music Playback',
        androidNotificationChannelDescription: 'Muxiz Audio streaming and lock screen media playback controls',
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidShowNotificationBadge: true,
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
        androidNotificationClickStartsActivity: true,
      ),
    ).timeout(const Duration(milliseconds: 1000), onTimeout: () => MuxizAudioHandler());
  } catch (e) {
    audioHandler = MuxizAudioHandler();
  }

  // Launch the app immediately on screen
  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const MuxizApp(),
    ),
  );

  // Load music catalog in background without delaying startup
  MockMusicCatalog.initializeCatalog().catchError((_) {});
}

class MuxizApp extends StatelessWidget {
  const MuxizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Muxiz',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainLayout(),
    );
  }
}
