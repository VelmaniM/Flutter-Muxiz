class AppConstants {
  static const String appName = 'Muxiz';
  static const String appTagline = 'Music for everyone';

  // API Backend URL (Configurable via --dart-define=API_BASE_URL=... or automatic platform-aware local fallbacks)
  static const String envApiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get defaultApiBaseUrl {
    if (envApiUrl.isNotEmpty) return envApiUrl;
    return 'http://192.168.1.94:5001/api/v1';
  }

  static List<String> get fallbackApiBaseUrls => [
    'http://192.168.1.94:5001/api/v1',
    'http://127.0.0.1:5001/api/v1',
    'http://localhost:5001/api/v1',
    'http://169.254.83.74:5001/api/v1',
    'http://10.0.2.2:5001/api/v1',
  ];

  // Fallback Cover Art (Empty: Uses sleek native placeholder icon & gradient)
  static const String defaultArtwork = '';
  static const String defaultArtistImage = '';

  // Storage Keys
  static const String keyFavorites = 'muxiz_favorites';
  static const String keyRecentlyPlayed = 'muxiz_recently_played';
  static const String keyCustomPlaylists = 'muxiz_custom_playlists';
  static const String keyDownloads = 'muxiz_downloaded_songs';
  static const String keyAuthToken = 'muxiz_auth_token';
  static const String keyUserData = 'muxiz_user_data';
  static const String keyAudioQuality = 'muxiz_audio_quality';
  static const String keyOfflineMode = 'muxiz_offline_mode';
  static const String keyCrossfade = 'muxiz_crossfade_seconds';
}
