import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/constants.dart';
import '../../shared/models/song.dart';
import '../../shared/models/playlist.dart';
import '../data/mock_catalog.dart';
import '../network/api_client.dart';

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  return FavoritesNotifier(ref);
});

final likedSongsProvider = StateNotifierProvider<LikedSongsNotifier, List<Song>>((ref) {
  return LikedSongsNotifier(ref);
});

class LikedSongsNotifier extends StateNotifier<List<Song>> {
  final Ref _ref;

  LikedSongsNotifier(this._ref) : super(LocalStorageService.getLikedSongs());

  void refresh() {
    state = LocalStorageService.getLikedSongs();
  }

  Future<bool> toggle(Song song) async {
    final willBeFav = await _ref.read(favoritesProvider.notifier).toggle(song);
    state = LocalStorageService.getLikedSongs();
    return willBeFav;
  }
}

class FavoritesNotifier extends StateNotifier<Set<String>> {
  final Ref _ref;

  FavoritesNotifier(this._ref) : super(LocalStorageService.getFavoriteSongIds().toSet()) {
    _syncFromRemote();
  }

  Future<void> _syncFromRemote() async {
    try {
      final remoteFavs = await _ref.read(apiClientProvider).fetchFavorites();
      if (remoteFavs.isNotEmpty) {
        for (final s in remoteFavs) {
          LocalStorageService.saveLikedSongLocally(s);
        }
        state = LocalStorageService.getFavoriteSongIds().toSet();
        _ref.read(likedSongsProvider.notifier).refresh();
      }
    } catch (_) {}
  }

  Future<bool> toggle(dynamic songOrId) async {
    final Song song;
    if (songOrId is Song) {
      song = songOrId;
    } else {
      final id = songOrId.toString();
      final liked = LocalStorageService.getLikedSongs().where((s) => s.id == id).firstOrNull;
      final found = MockMusicCatalog.allSongs.where((s) => s.id == id).firstOrNull;
      song = liked ?? found ?? Song(
        id: id,
        title: 'Track',
        artist: 'Artist',
        album: 'Single',
        audioUrl: '',
        artworkUrl: '',
        duration: 180,
      );
    }

    final bool willBeFav = await LocalStorageService.toggleFavoriteSong(song);
    state = LocalStorageService.getFavoriteSongIds().toSet();
    _ref.read(likedSongsProvider.notifier).refresh();

    // Call API in background
    try {
      await _ref.read(apiClientProvider).toggleLike(song.id);
    } catch (_) {}

    return willBeFav;
  }

  bool isFav(String songId) => state.contains(songId);
}

final customPlaylistsProvider = StateNotifierProvider<CustomPlaylistsNotifier, List<Playlist>>((ref) {
  return CustomPlaylistsNotifier(ref);
});

class CustomPlaylistsNotifier extends StateNotifier<List<Playlist>> {
  final Ref _ref;

  CustomPlaylistsNotifier(this._ref) : super(LocalStorageService.getCustomPlaylists()) {
    _syncFromRemote();
  }

  Future<void> _syncFromRemote() async {
    try {
      final remotePlaylists = await _ref.read(apiClientProvider).fetchPlaylists();
      if (remotePlaylists.isNotEmpty) {
        for (final p in remotePlaylists) {
          await LocalStorageService.saveCustomPlaylist(p);
        }
        state = LocalStorageService.getCustomPlaylists();
      }
    } catch (_) {}
  }

  Future<Playlist> createPlaylist(String title, {Song? initialSong}) async {
    final newPlaylist = Playlist(
      id: 'playlist_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: 'Created by You',
      coverUrl: initialSong?.artworkUrl ?? '',
      creator: 'You',
      songs: initialSong != null ? [initialSong] : [],
    );
    await LocalStorageService.saveCustomPlaylist(newPlaylist);
    state = LocalStorageService.getCustomPlaylists();

    // Sync to PostgreSQL backend
    try {
      final remoteCreated = await _ref.read(apiClientProvider).createPlaylist(
        title,
        cover: newPlaylist.coverUrl,
        initialSongId: initialSong?.id,
      );
      if (remoteCreated != null) {
        // Replace temp local playlist with server playlist
        await LocalStorageService.deleteCustomPlaylist(newPlaylist.id);
        await LocalStorageService.saveCustomPlaylist(remoteCreated);
        state = LocalStorageService.getCustomPlaylists();
        return remoteCreated;
      }
    } catch (_) {}

    return newPlaylist;
  }

  Future<({bool success, bool added, bool alreadyExists})> addSongToPlaylist(String playlistId, Song song) async {
    final playlists = LocalStorageService.getCustomPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      final p = playlists[index];
      final exists = p.songs.any((s) => s.id == song.id);
      if (exists) {
        return (success: true, added: false, alreadyExists: true);
      }

      final updatedSongs = List<Song>.from(p.songs)..insert(0, song);
      final updatedPlaylist = p.copyWith(
        songs: updatedSongs,
        coverUrl: updatedSongs.isNotEmpty ? updatedSongs.first.artworkUrl : p.coverUrl,
      );
      await LocalStorageService.saveCustomPlaylist(updatedPlaylist);
      state = LocalStorageService.getCustomPlaylists();

      // Sync with backend
      try {
        await _ref.read(apiClientProvider).addSongToPlaylist(playlistId, song.id);
      } catch (_) {}

      return (success: true, added: true, alreadyExists: false);
    }
    return (success: false, added: false, alreadyExists: false);
  }

  Future<bool> toggleSongInPlaylist(String playlistId, Song song) async {
    final res = await addSongToPlaylist(playlistId, song);
    if (res.alreadyExists) {
      await removeSongFromPlaylist(playlistId, song.id);
      return false; // Removed
    }
    return res.added;
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final playlists = LocalStorageService.getCustomPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      final p = playlists[index];
      final updatedSongs = List<Song>.from(p.songs)..removeWhere((s) => s.id == songId);
      final updatedPlaylist = p.copyWith(
        songs: updatedSongs,
        coverUrl: updatedSongs.isNotEmpty ? updatedSongs.first.artworkUrl : p.coverUrl,
      );
      await LocalStorageService.saveCustomPlaylist(updatedPlaylist);
      state = LocalStorageService.getCustomPlaylists();

      // Sync delete with backend
      try {
        await _ref.read(apiClientProvider).removeSongFromPlaylist(playlistId, songId);
      } catch (_) {}
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    await LocalStorageService.deleteCustomPlaylist(playlistId);
    state = LocalStorageService.getCustomPlaylists();
    try {
      await _ref.read(apiClientProvider).deletePlaylist(playlistId);
    } catch (_) {}
  }
}

class LocalStorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    // Wipe all cached songs and playlists so app starts 100% fresh with 0 songs
    await _prefs?.remove('muxiz_catalog_songs');
    await _prefs?.remove('muxiz_liked_songs');
    await _prefs?.remove('muxiz_custom_playlists');
    await _prefs?.remove('muxiz_recently_played');
    await _prefs?.remove(AppConstants.keyFavorites);
  }

  static Future<void> clearAllData() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.clear();
    await _prefs?.setBool('muxiz_fresh_v3_reset_done', true);
  }

  // --- Splash Screen Launch Persistence ---
  static const String keyHasSeenSplash = 'muxiz_has_seen_splash';

  static bool hasSeenSplash() {
    return _prefs?.getBool(keyHasSeenSplash) ?? false;
  }

  static Future<void> markSplashSeen() async {
    await _prefs?.setBool(keyHasSeenSplash, true);
  }

  // --- User Authentication & Session Token ---
  static String? getAuthToken() {
    return _prefs?.getString(AppConstants.keyAuthToken);
  }

  static Future<void> setAuthToken(String token) async {
    await _prefs?.setString(AppConstants.keyAuthToken, token);
  }

  static Future<void> clearAuthToken() async {
    await _prefs?.remove(AppConstants.keyAuthToken);
    await _prefs?.remove(AppConstants.keyUserData);
  }

  static Map<String, dynamic>? getUserData() {
    final raw = _prefs?.getString(AppConstants.keyUserData);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setUserData(Map<String, dynamic> data) async {
    await _prefs?.setString(AppConstants.keyUserData, jsonEncode(data));
  }

  static String getUserId() {
    final userData = getUserData();
    if (userData != null && userData['id'] != null) {
      return userData['id'].toString();
    }
    return 'listener-001';
  }

  static String getUserName() {
    final userData = getUserData();
    if (userData != null && userData['name'] != null && userData['name'].toString().trim().isNotEmpty) {
      return userData['name'].toString();
    }
    return _prefs?.getString('muxiz_user_name') ?? 'Velmani Kandan';
  }

  static Future<void> saveUserName(String name) async {
    await _prefs?.setString('muxiz_user_name', name.trim());
    final current = getUserData() ?? {};
    current['name'] = name.trim();
    await setUserData(current);
  }

  static String? getUserAvatar() {
    final userData = getUserData();
    if (userData != null && userData['avatar'] != null && userData['avatar'].toString().trim().isNotEmpty) {
      return userData['avatar'].toString();
    }
    return _prefs?.getString('muxiz_user_avatar');
  }

  static Future<void> saveUserAvatar(String avatarUrl) async {
    await _prefs?.setString('muxiz_user_avatar', avatarUrl);
    final current = getUserData() ?? {};
    current['avatar'] = avatarUrl;
    await setUserData(current);
  }

  static Future<void> saveUserProfile(String name, String? avatarUrl) async {
    await saveUserName(name);
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      await saveUserAvatar(avatarUrl);
    }
  }

  // --- Favorites & Liked Songs ---
  static List<String> getFavoriteSongIds() {
    final raw = _prefs?.getStringList(AppConstants.keyFavorites) ?? [];
    return raw;
  }

  static List<Song> getLikedSongs() {
    final favIds = getFavoriteSongIds().toSet();
    final activeIds = MockMusicCatalog.allSongs.map((s) => s.id).toSet();
    final validFavIds = favIds.intersection(activeIds);

    final List<Song> result = [];
    for (final id in validFavIds) {
      final found = MockMusicCatalog.allSongs.where((s) => s.id == id).firstOrNull;
      if (found != null) {
        result.add(found.copyWith(isFavorite: true));
      }
    }
    return result;
  }

  static Future<void> saveLikedSongLocally(Song song) async {
    final favIds = getFavoriteSongIds().toSet();
    final bool willBeFavorite;

    if (favIds.contains(song.id)) {
      favIds.remove(song.id);
      willBeFavorite = false;
    } else {
      favIds.add(song.id);
      willBeFavorite = true;
    }

    await _prefs?.setStringList(AppConstants.keyFavorites, favIds.toList());
    _syncFavoriteWithBackend(song.id, willBeFavorite);
    return;
  }

  static Future<bool> toggleFavoriteSong(Song song) async {
    final favIds = getFavoriteSongIds().toSet();
    final bool willBeFavorite;

    if (favIds.contains(song.id)) {
      favIds.remove(song.id);
      willBeFavorite = false;
    } else {
      favIds.add(song.id);
      willBeFavorite = true;
    }

    await _prefs?.setStringList(AppConstants.keyFavorites, favIds.toList());

    // Asynchronously notify NestJS PostgreSQL backend
    _syncFavoriteWithBackend(song.id, willBeFavorite);

    return willBeFavorite;
  }

  static Future<bool> toggleFavorite(String songId) async {
    final song = MockMusicCatalog.allSongs.where((s) => s.id == songId).firstOrNull;
    if (song == null) return false;
    return toggleFavoriteSong(song);
  }

  static bool isFavorite(String songId) {
    return getFavoriteSongIds().contains(songId);
  }

  static void _syncFavoriteWithBackend(String songId, bool isLiked) {
    try {
      final dio = Dio();
      dio.post(
        '${AppConstants.defaultApiBaseUrl}/songs/$songId/like',
        data: {'userId': 'listener-001'},
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      ).catchError((_) => Response(requestOptions: RequestOptions()));
    } catch (_) {}
  }

  // --- Recently Played ---
  static List<Song> getRecentlyPlayed() {
    final raw = _prefs?.getString(AppConstants.keyRecentlyPlayed);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      final activeIds = MockMusicCatalog.allSongs.map((s) => s.id).toSet();
      return list
          .map((item) => Song.fromJson(item as Map<String, dynamic>))
          .where((s) => activeIds.contains(s.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addRecentlyPlayed(Song song) async {
    var list = getRecentlyPlayed();
    list.removeWhere((s) => s.id == song.id);
    list.insert(0, song);
    if (list.length > 50) {
      list = list.sublist(0, 50);
    }
    final raw = jsonEncode(list.map((s) => s.toJson()).toList());
    await _prefs?.setString(AppConstants.keyRecentlyPlayed, raw);

    // Sync recently played and listening history to PostgreSQL DB
    _syncRecentlyPlayedWithBackend(song.id);
    _syncListeningHistoryWithBackend(song.id, durationSec: song.duration);
  }

  static void _syncRecentlyPlayedWithBackend(String songId) {
    try {
      final dio = Dio();
      dio.post(
        '${AppConstants.defaultApiBaseUrl}/users/recently-played/$songId',
        options: Options(
          headers: {'x-user-id': 'listener-001'},
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      ).catchError((_) => Response(requestOptions: RequestOptions()));
    } catch (_) {}
  }

  static void _syncListeningHistoryWithBackend(String songId, {int durationSec = 180}) {
    try {
      final dio = Dio();
      dio.post(
        '${AppConstants.defaultApiBaseUrl}/users/history',
        data: {
          'songId': songId,
          'duration': durationSec,
        },
        options: Options(
          headers: {'x-user-id': 'listener-001'},
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      ).catchError((_) => Response(requestOptions: RequestOptions()));
    } catch (_) {}
  }

  // --- Custom Playlists ---
  static List<Playlist> getCustomPlaylists() {
    final raw = _prefs?.getString(AppConstants.keyCustomPlaylists);
    if (raw == null || raw.isEmpty) return [];
    try {
      final deleted = getDeletedPlaylistIds();
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((item) => Playlist.fromJson(item as Map<String, dynamic>))
          .where((p) => !deleted.contains(p.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCustomPlaylist(Playlist playlist) async {
    final playlists = getCustomPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlist.id);
    if (index >= 0) {
      playlists[index] = playlist;
    } else {
      playlists.insert(0, playlist);
    }
    final raw = jsonEncode(playlists.map((p) => p.toJson()).toList());
    await _prefs?.setString(AppConstants.keyCustomPlaylists, raw);

    // Asynchronously sync and save in PostgreSQL DB
    _syncPlaylistWithBackend(playlist);
  }

  static void _syncPlaylistWithBackend(Playlist playlist) {
    try {
      final dio = Dio();
      dio.post(
        '${AppConstants.defaultApiBaseUrl}/playlists',
        data: {
          'title': playlist.title,
          'description': playlist.description,
          'cover': playlist.coverUrl,
          'userId': 'listener-001',
        },
        options: Options(
          headers: {'x-user-id': 'listener-001'},
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      ).catchError((_) => Response(requestOptions: RequestOptions()));
    } catch (_) {}
  }

  static Future<void> deleteCustomPlaylist(String playlistId) async {
    final playlists = getCustomPlaylists();
    playlists.removeWhere((p) => p.id == playlistId);
    final raw = jsonEncode(playlists.map((p) => p.toJson()).toList());
    await _prefs?.setString(AppConstants.keyCustomPlaylists, raw);

    // Delete in PostgreSQL DB
    _syncDeletePlaylistWithBackend(playlistId);
  }

  static void _syncDeletePlaylistWithBackend(String playlistId) {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
      ));
      for (final baseUrl in [AppConstants.defaultApiBaseUrl, ...AppConstants.fallbackApiBaseUrls]) {
        try {
          dio.delete(
            '$baseUrl/playlists/$playlistId',
            options: Options(
              headers: {'x-user-id': 'listener-001'},
            ),
          ).catchError((_) => Response(requestOptions: RequestOptions()));
        } catch (_) {}
      }
    } catch (_) {}
  }

  // --- Downloaded Songs ---
  static List<Song> getDownloadedSongs() {
    final raw = _prefs?.getString(AppConstants.keyDownloads);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((item) => Song.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveDownloadedSong(Song song) async {
    final downloads = getDownloadedSongs();
    downloads.removeWhere((s) => s.id == song.id);
    downloads.insert(0, song.copyWith(isDownloaded: true));
    final raw = jsonEncode(downloads.map((s) => s.toJson()).toList());
    await _prefs?.setString(AppConstants.keyDownloads, raw);

    // Sync download record to PostgreSQL
    _syncDownloadWithBackend(song.id, isAdded: true);
  }

  static Future<void> removeDownloadedSong(String songId) async {
    final downloads = getDownloadedSongs();
    downloads.removeWhere((s) => s.id == songId);
    final raw = jsonEncode(downloads.map((s) => s.toJson()).toList());
    await _prefs?.setString(AppConstants.keyDownloads, raw);

    // Remove download record in PostgreSQL
    _syncDownloadWithBackend(songId, isAdded: false);
  }

  static void _syncDownloadWithBackend(String songId, {required bool isAdded}) {
    try {
      final dio = Dio();
      if (isAdded) {
        dio.post(
          '${AppConstants.defaultApiBaseUrl}/users/downloads',
          data: {'songId': songId, 'deviceId': 'ios-device', 'fileSize': 1024000},
          options: Options(
            headers: {'x-user-id': 'listener-001'},
            sendTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 3),
          ),
        ).catchError((_) => Response(requestOptions: RequestOptions()));
      } else {
        dio.delete(
          '${AppConstants.defaultApiBaseUrl}/users/downloads/$songId',
          options: Options(
            headers: {'x-user-id': 'listener-001'},
            sendTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 3),
          ),
        ).catchError((_) => Response(requestOptions: RequestOptions()));
      }
    } catch (_) {}
  }

  // --- Library View Mode & Columns (List, 3-Columns, 4-Columns) ---
  static bool getLibraryIsGridView() {
    return _prefs?.getBool('library_view_is_grid') ?? true;
  }

  static Future<void> setLibraryIsGridView(bool isGrid) async {
    await _prefs?.setBool('library_view_is_grid', isGrid);
  }

  static int getLibraryGridColumns() {
    return _prefs?.getInt('library_grid_columns') ?? 3;
  }

  static Future<void> setLibraryGridColumns(int cols) async {
    await _prefs?.setInt('library_grid_columns', cols);
  }

  // --- Persistent Playback State (Preserved across app restarts) ---
  static Future<void> savePlaybackState({
    required Song song,
    required Duration position,
    required List<Song> queue,
    required int queueIndex,
  }) async {
    try {
      await _prefs?.setString('last_played_song', jsonEncode(song.toJson()));
      await _prefs?.setInt('last_playback_position_ms', position.inMilliseconds);
      if (queue.isNotEmpty) {
        final queueJson = jsonEncode(queue.take(50).map((s) => s.toJson()).toList());
        await _prefs?.setString('last_playback_queue', queueJson);
      }
      await _prefs?.setInt('last_playback_queue_index', queueIndex);
    } catch (_) {}
  }

  static ({Song? song, Duration position, List<Song> queue, int queueIndex}) getLastPlaybackState() {
    try {
      final songRaw = _prefs?.getString('last_played_song');
      final posMs = _prefs?.getInt('last_playback_position_ms') ?? 0;
      final queueRaw = _prefs?.getString('last_playback_queue');
      final queueIndex = _prefs?.getInt('last_playback_queue_index') ?? 0;

      Song? song;
      if (songRaw != null && songRaw.isNotEmpty) {
        song = Song.fromJson(jsonDecode(songRaw));
      }

      List<Song> queue = [];
      if (queueRaw != null && queueRaw.isNotEmpty) {
        final List<dynamic> qList = jsonDecode(queueRaw);
        queue = qList.map((item) => Song.fromJson(item as Map<String, dynamic>)).toList();
      }

      return (
        song: song,
        position: Duration(milliseconds: posMs),
        queue: queue,
        queueIndex: queueIndex,
      );
    } catch (_) {
      return (
        song: null,
        position: Duration.zero,
        queue: <Song>[],
        queueIndex: 0,
      );
    }
  }

  // --- Deleted Songs & Playlists Blacklist (Strict Persistence) ---
  static const String keyDeletedSongs = 'muxiz_deleted_songs_blacklist';
  static const String keyDeletedPlaylists = 'muxiz_deleted_playlists_blacklist';

  static Set<String> getDeletedSongIds() {
    final list = _prefs?.getStringList(keyDeletedSongs);
    return list?.toSet() ?? <String>{};
  }

  static Future<void> addDeletedSongId(String songId) async {
    final set = getDeletedSongIds()..add(songId);
    await _prefs?.setStringList(keyDeletedSongs, set.toList());
  }

  static Set<String> getDeletedPlaylistIds() {
    final list = _prefs?.getStringList(keyDeletedPlaylists);
    return list?.toSet() ?? <String>{};
  }

  static Future<void> addDeletedPlaylistId(String playlistId) async {
    final set = getDeletedPlaylistIds()..add(playlistId);
    await _prefs?.setStringList(keyDeletedPlaylists, set.toList());
  }

  // --- Complete Local Storage Song Deletion ---
  static Future<void> removeSongEverywhere(String songId) async {
    try {
      // 0. Add to deleted songs blacklist
      await addDeletedSongId(songId);

      // 1. Remove from Favorites & Liked Songs
      final favIds = getFavoriteSongIds().toSet()..remove(songId);
      await _prefs?.setStringList(AppConstants.keyFavorites, favIds.toList());
      final likedList = getLikedSongs().where((s) => s.id != songId).toList();
      await _prefs?.setString('muxiz_liked_songs', jsonEncode(likedList.map((s) => s.toJson()).toList()));

      // 2. Remove from Recently Played
      final recent = getRecentlyPlayed().where((s) => s.id != songId).toList();
      await _prefs?.setString(AppConstants.keyRecentlyPlayed, jsonEncode(recent.map((s) => s.toJson()).toList()));

      // 3. Remove from Downloads
      final downloads = getDownloadedSongs().where((s) => s.id != songId).toList();
      await _prefs?.setString(AppConstants.keyDownloads, jsonEncode(downloads.map((s) => s.toJson()).toList()));

      // 4. Remove from Custom Playlists
      final playlists = getCustomPlaylists();
      for (final p in playlists) {
        p.songs.removeWhere((s) => s.id == songId);
      }
      await _prefs?.setString(AppConstants.keyCustomPlaylists, jsonEncode(playlists.map((p) => p.toJson()).toList()));

      // 5. Update cached catalog entries directly (filter out deleted song)
      final catalog = getCatalogSongsLocally().where((s) => s.id != songId).toList();
      await saveCatalogSongsLocally(catalog);
    } catch (_) {}
  }

  // --- Persistent Song Catalog Sync with Strict Deduplication ---
  static const String keyPersistentCatalog = 'muxiz_persistent_catalog_songs';

  static Future<void> saveCatalogSongsLocally(List<Song> songs) async {
    try {
      final deletedIds = getDeletedSongIds();
      final Map<String, Song> uniqueMap = {};

      for (final s in songs) {
        if (deletedIds.contains(s.id)) continue;
        final dedupeKey = '${s.title.trim().toLowerCase()}:::${s.artist.trim().toLowerCase()}';
        // Prefer downloaded or richer version
        if (!uniqueMap.containsKey(dedupeKey) || (!uniqueMap[dedupeKey]!.isDownloaded && s.isDownloaded)) {
          uniqueMap[dedupeKey] = s;
        }
      }

      final jsonList = uniqueMap.values.map((s) => s.toJson()).toList();
      await _prefs?.setString(keyPersistentCatalog, jsonEncode(jsonList));
    } catch (_) {}
  }

  static List<Song> getCatalogSongsLocally() {
    try {
      final raw = _prefs?.getString(keyPersistentCatalog);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      final deletedIds = getDeletedSongIds();
      final Map<String, Song> uniqueMap = {};

      for (final item in list) {
        final s = Song.fromJson(item as Map<String, dynamic>);
        if (deletedIds.contains(s.id)) continue;
        final dedupeKey = '${s.title.trim().toLowerCase()}:::${s.artist.trim().toLowerCase()}';
        if (!uniqueMap.containsKey(dedupeKey)) {
          uniqueMap[dedupeKey] = s;
        }
      }

      return uniqueMap.values.toList();
    } catch (_) {
      return [];
    }
  }

  // --- Dynamic Recent Searches ---
  static const String keyRecentSearches = 'muxiz_recent_searches';

  static List<String> getRecentSearches() {
    return _prefs?.getStringList(keyRecentSearches) ?? [];
  }

  static Future<void> addRecentSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    final current = getRecentSearches().toList();
    current.removeWhere((item) => item.toLowerCase() == clean.toLowerCase());
    current.insert(0, clean);
    if (current.length > 20) {
      current.removeLast();
    }
    await _prefs?.setStringList(keyRecentSearches, current);
  }

  static Future<void> removeRecentSearch(String query) async {
    final current = getRecentSearches().toList();
    current.removeWhere((item) => item.toLowerCase() == query.trim().toLowerCase());
    await _prefs?.setStringList(keyRecentSearches, current);
  }

  static Future<void> clearRecentSearches() async {
    await _prefs?.remove(keyRecentSearches);
  }

  // --- Dynamic Music Sorting Preference ---
  static const String keyMusicSortOption = 'muxiz_music_sort_option';

  static String getMusicSortOption() {
    return _prefs?.getString(keyMusicSortOption) ?? 'recentlyAdded';
  }

  static Future<void> saveMusicSortOption(String sortOptionName) async {
    await _prefs?.setString(keyMusicSortOption, sortOptionName);
  }
}
