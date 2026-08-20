import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app/theme.dart';
import 'core/audio/audio_manager.dart';
import 'core/data/mock_catalog.dart';
import 'core/services/remote_sync_service.dart';
import 'core/storage/local_storage.dart';
import 'features/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase safely
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}

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

  // Initialize local storage safely and load cached catalog in 0ms
  try {
    await LocalStorageService.init();
    final cached = LocalStorageService.getCatalogSongsLocally();
    if (cached.isNotEmpty) {
      MockMusicCatalog.allSongs = cached;
      MockMusicCatalog.isInitialized = true;
    }
    // Fast pre-fetch with live studio database before Home UI renders
    await MockMusicCatalog.initializeCatalog().timeout(const Duration(milliseconds: 4000), onTimeout: () {});
  } catch (_) {}

  // Check if this is the 1st time or 2nd time onwards
  final bool isFirstTime = !LocalStorageService.hasSeenSplash();
  if (isFirstTime) {
    LocalStorageService.markSplashSeen();
  }

  // Initialize background AudioService safely with proper native registration
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
    );
  } catch (e) {
    audioHandler = MuxizAudioHandler();
  }

  // Launch the app immediately on screen with full preloaded data
  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const MuxizApp(),
    ),
  );
}

class MuxizApp extends StatefulWidget {
  const MuxizApp({super.key});

  @override
  State<MuxizApp> createState() => _MuxizAppState();
}

class _MuxizAppState extends State<MuxizApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start continuous background auto-sync
    MockMusicCatalog.startAutoSync();
    // Start real-time remote sync & cache wipe listener
    RemoteSyncService.instance.start();
  }

  @override
  void dispose() {
    RemoteSyncService.instance.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-sync catalog as soon as user switches back to the app
      MockMusicCatalog.initializeCatalog(background: true);
      // Check for any remote cache wipe triggered while app was in background
      RemoteSyncService.instance.checkEpochAndWipeIfNeeded();
    }
  }

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
