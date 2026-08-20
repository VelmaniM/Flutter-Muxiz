import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/constants.dart';
import '../../shared/models/song.dart';
import '../../shared/models/artist.dart';
import '../../shared/models/album.dart';
import '../../shared/models/playlist.dart';
import '../storage/local_storage.dart';

class CatalogNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final catalogNotifier = CatalogNotifier();
final musicCatalogProvider = ChangeNotifierProvider<CatalogNotifier>((ref) => catalogNotifier);

class MockMusicCatalog {
  static List<Song> allSongs = [];
  static List<Artist> popularArtists = [];
  static List<Playlist> featuredPlaylists = [];
  static List<Album> topAlbums = [];
  static bool isInitialized = false;
  static bool isServerLive = true;
  static bool isLoading = false;
  static String serverStatus = 'ONLINE';
  static Map<String, String> artistPortraits = {};

  static String _songDedupKey(Song s) {
    final title = s.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final movie = (s.movieName ?? s.album).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '${title}___$movie';
  }

  /// Converts any string dynamically to Title Case with proper capitalization for initials (e.g. A.R. Rahman, S.P.B)
  static String toDynamicTitleCase(String input) {
    if (input.trim().isEmpty) return '';
    final words = input.trim().split(RegExp(r'\s+'));
    final formattedWords = words.map((w) {
      if (w.isEmpty) return '';
      if (w.contains('.')) {
        return w.split('.').map((part) {
          if (part.isEmpty) return '';
          if (part.length == 1) return part.toUpperCase();
          return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
        }).join('.');
      }
      if (w.length == 1) return w.toUpperCase();
      return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
    });
    return formattedWords.join(' ');
  }

  /// Cleans watermarks, special characters, and formats raw artist string purely dynamically
  static String normalizeSingleArtist(String raw) {
    if (raw.trim().isEmpty) return '';
    var clean = raw
        .replaceAll(RegExp(r'(masstamilan|isaimini|starmusiq|tamiltunes|sensongs|kuttyweb|tamilwire)(\.(com|org|in|net|co|fun|cc|xyz))?', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(masstamilan|isaimini|starmusiq|tamiltunes|sensongs|kuttyweb|tamilwire)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'^[\s\-–—:._,]+|[\s\-–—:._,]+$'), '')
        .trim();

    return toDynamicTitleCase(clean);
  }

  /// Fully dynamically extracts individual artists from any uploaded compound string
  /// (e.g., "Artist 1, Artist 2 feat. Artist 3 & Artist 4" -> [Artist 1, Artist 2, Artist 3, Artist 4])
  static List<String> extractArtistsList(String raw) {
    if (raw.trim().isEmpty) return [];
    final parts = raw
        .replaceAll(RegExp(r'\s+(feat\.|ft\.|featuring|with|x|vs|\/)\s+', caseSensitive: false), ', ')
        .replaceAll(RegExp(r'\s+&\s+'), ', ')
        .replaceAll(RegExp(r'\s+and\s+', caseSensitive: false), ', ')
        .split(RegExp(r'[,;]'));

    final List<String> list = [];
    final Set<String> seen = {};
    for (final p in parts) {
      final norm = normalizeSingleArtist(p);
      if (norm.length >= 2) {
        final lower = norm.toLowerCase();
        if (!['unknown artist', 'various artists', 'unknown', 'various'].contains(lower) && !seen.contains(lower)) {
          seen.add(lower);
          list.add(norm);
        }
      }
    }
    return list.isNotEmpty ? list : [normalizeSingleArtist(raw).isNotEmpty ? normalizeSingleArtist(raw) : 'Unknown Artist'];
  }

  static String normalizeArtistName(String raw) {
    final clean = normalizeSingleArtist(raw);
    return clean.isNotEmpty ? clean : 'Unknown Artist';
  }

  static List<Song> getSongsForArtist(String artistName) {
    final target = normalizeSingleArtist(artistName).toLowerCase();
    return allSongs.where((s) {
      final artists = extractArtistsList(s.artist).map((a) => a.toLowerCase());
      return artists.contains(target) || s.artist.toLowerCase().contains(target);
    }).toList();
  }

  static bool isSongByArtist(Song s, String artistName) {
    final target = normalizeSingleArtist(artistName).toLowerCase();
    final artists = extractArtistsList(s.artist).map((a) => a.toLowerCase());
    return artists.contains(target) || s.artist.toLowerCase().contains(target);
  }

  static String normalizeMovieOrAlbumName(Song s) {
    if (s.movieName != null && s.movieName!.trim().isNotEmpty && s.movieName != 'Single') {
      return s.movieName!.trim();
    }
    if (s.album.trim().isNotEmpty && s.album != 'Single') {
      return s.album.trim();
    }
    return 'Single';
  }

  static void removeSong(String songId) {
    allSongs.removeWhere((s) => s.id == songId);
    _buildArtistsAndAlbums();
    _buildPlaylists();
    LocalStorageService.saveCatalogSongsLocally(allSongs);
    catalogNotifier.notify();
  }

  static void syncSong(Song song) {
    allSongs.removeWhere((s) => s.id == song.id);
    allSongs.insert(0, song);
    _buildArtistsAndAlbums();
    _buildPlaylists();
    LocalStorageService.saveCatalogSongsLocally(allSongs);
    catalogNotifier.notify();
  }

  static bool _isSyncing = false;
  static bool _autoSyncStarted = false;
  static Timer? _heartbeatTimer;

  static List<String> get candidateBaseUrls => [
    'http://localhost:5001/api/v1',
    'http://127.0.0.1:5001/api/v1',
    'http://192.168.1.94:5001/api/v1',
    'http://10.0.2.2:5001/api/v1',
    'https://flutter-muxiz.onrender.com/api/v1',
    'https://muxizstudio.vercel.app/api',
    AppConstants.defaultApiBaseUrl,
  ];

  static void startAutoSync() {
    if (_autoSyncStarted) return;
    _autoSyncStarted = true;

    // Optional background check for live studio updates
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkServerStatusHeartbeat();
    });
  }

  static Future<void> _checkServerStatusHeartbeat() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    for (final base in candidateBaseUrls) {
      try {
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(milliseconds: 1500),
          receiveTimeout: const Duration(milliseconds: 1500),
        ));
        final res = await dio.get('$base/server/status?t=$timestamp');
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data;
          final bool active = data is Map ? (data['active'] == true) : false;
          if (active) {
            isServerLive = true;
            serverStatus = 'ONLINE';
            break;
          }
        }
      } catch (_) {}
    }
  }

  /// Initializes the catalog from local cache and triggers live Studio background sync
  static Future<void> initializeCatalog({bool forceRefresh = false, bool background = false}) async {
    if (allSongs.isEmpty) {
      final local = LocalStorageService.getCatalogSongsLocally();
      if (local.isNotEmpty) {
        allSongs = local;
      }
    }

    _buildArtistsAndAlbums();
    _buildPlaylists();
    isInitialized = true;
    isServerLive = true;
    isLoading = false;
    serverStatus = 'ONLINE';
    catalogNotifier.notify();

    // Trigger live background fetch from Studio backend
    if (!_isSyncing) {
      _fetchRemoteCatalogInBackground();
    }
  }

  static Future<void> _fetchRemoteCatalogInBackground() async {
    _isSyncing = true;
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      for (final base in candidateBaseUrls) {
        try {
          final dio = Dio(BaseOptions(
            connectTimeout: const Duration(milliseconds: 2000),
            receiveTimeout: const Duration(milliseconds: 3000),
          ));

          // 1. Fetch Songs from Studio
          final res = await dio.get('$base/songs?limit=1000&t=$timestamp');
          if (res.statusCode == 200 && res.data != null) {
            final data = res.data;
            final list = (data is Map ? (data['data'] ?? data['songs']) : data) as List<dynamic>?;
            if (list != null && list.isNotEmpty) {
              final List<Song> remoteSongs = [];
              for (final item in list) {
                final id = (item['id'] ?? '').toString();
                if (id.isEmpty) continue;
                final rawArt = (item['artworkUrl'] ?? item['artwork'] ?? '').toString();
                final cleanArt = rawArt.replaceAll('/1400x1400bb.jpg', '/600x600bb.jpg');

                remoteSongs.add(Song(
                  id: id,
                  title: (item['title'] ?? 'Untitled Track').toString(),
                  artist: (item['artistName'] ?? item['artist']?['name'] ?? item['artist'] ?? 'Unknown Artist').toString(),
                  album: (item['albumName'] ?? item['album']?['title'] ?? item['album'] ?? 'Single').toString(),
                  movieName: item['movieName']?.toString(),
                  artworkUrl: cleanArt.isNotEmpty ? cleanArt : 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/64/00/f5/6400f57c-2b63-fa91-d8ec-8f43c3d526e0/8903431940989_cover.jpg/600x600bb.jpg',
                  audioUrl: (item['audioUrl'] ?? '').toString(),
                  duration: (item['duration'] as num?)?.toInt() ?? 210,
                  genre: (item['genre'] ?? 'Melody').toString(),
                  language: (item['language'] ?? 'Tamil').toString(),
                  lyrics: (item['lyrics'] is List) ? List<String>.from(item['lyrics']) : [],
                ));
              }

              if (remoteSongs.isNotEmpty) {
                allSongs = remoteSongs;

                // 2. Fetch Artists Directly from Studio Backend (/artists or /songs/artists/all)
                try {
                  final artistEndpoint = base.endsWith('/v1')
                      ? '$base/songs/artists/all?t=$timestamp'
                      : '$base/artists?t=$timestamp';
                  final aRes = await dio.get(artistEndpoint);
                  if (aRes.statusCode == 200 && aRes.data != null) {
                    final aData = aRes.data;
                    final aList = (aData is Map ? (aData['data'] ?? aData['artists']) : aData) as List<dynamic>?;
                    if (aList != null && aList.isNotEmpty) {
                      for (final a in aList) {
                        final aName = (a['name'] ?? '').toString().trim();
                        final aImg = (a['image'] ?? a['imageUrl'] ?? a['artwork'] ?? '').toString();
                        if (aName.isNotEmpty && aImg.isNotEmpty) {
                          artistPortraits[aName.toLowerCase()] = aImg;
                          artistPortraits[aName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')] = aImg;
                        }
                      }
                    }
                  }
                } catch (_) {}

                _buildArtistsAndAlbums();
                _buildPlaylists();
                LocalStorageService.saveCatalogSongsLocally(allSongs);
                catalogNotifier.notify();
                break;
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {} finally {
      _isSyncing = false;
      startAutoSync();
    }
  }

  static void _buildArtistsAndAlbums() {
    if (allSongs.isEmpty) {
      popularArtists = [];
      topAlbums = [];
      return;
    }

    final Map<String, List<Song>> artistMap = {};
    final Map<String, List<Song>> albumMap = {};
    final Map<String, Set<String>> artistSongKeys = {};
    final Map<String, Set<String>> albumSongKeys = {};

    for (final s in allSongs) {
      final individualArtists = extractArtistsList(s.artist);
      for (final artistName in individualArtists) {
        if (artistName.isNotEmpty && artistName != 'Various Artists') {
          artistSongKeys.putIfAbsent(artistName, () => {});
          if (!artistSongKeys[artistName]!.contains(s.id)) {
            artistSongKeys[artistName]!.add(s.id);
            artistMap.putIfAbsent(artistName, () => []).add(s);
          }
        }
      }

      final movieOrAlbum = normalizeMovieOrAlbumName(s);
      if (movieOrAlbum.isNotEmpty && movieOrAlbum != 'Single') {
        albumSongKeys.putIfAbsent(movieOrAlbum, () => {});
        if (!albumSongKeys[movieOrAlbum]!.contains(s.id)) {
          albumSongKeys[movieOrAlbum]!.add(s.id);
          albumMap.putIfAbsent(movieOrAlbum, () => []).add(s);
        }
      }
    }

    final sortedArtistEntries = artistMap.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    popularArtists = sortedArtistEntries.map((e) {
      final firstSong = e.value.first;
      final artistKey = e.key.toLowerCase().trim();
      final normKey = artistKey.replaceAll(RegExp(r'[^a-z0-9]'), '');
      final cachedPortrait = artistPortraits[normKey] ?? artistPortraits[artistKey];
      final realPortrait = (cachedPortrait != null && cachedPortrait.isNotEmpty)
          ? cachedPortrait
          : firstSong.artworkUrl;

      return Artist(
        id: e.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
        name: e.key,
        imageUrl: realPortrait,
        monthlyListeners: '${(e.value.length * 1.5).toStringAsFixed(1)}M',
        bio: 'Artist with ${e.value.length}+ tracks in catalog.',
        topTracks: e.value,
      );
    }).toList();

    final sortedAlbumEntries = albumMap.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    topAlbums = sortedAlbumEntries.map((e) {
      final firstSong = e.value.first;
      final Map<String, int> artistCounts = {};
      for (final s in e.value) {
        final a = normalizeArtistName(s.artist);
        if (a.isNotEmpty && a != 'Various Artists') {
          artistCounts[a] = (artistCounts[a] ?? 0) + 1;
        }
      }
      final primaryAlbumArtist = artistCounts.isNotEmpty
          ? (artistCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key
          : normalizeArtistName(firstSong.artist);

      return Album(
        id: e.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
        title: e.key,
        artist: primaryAlbumArtist,
        artworkUrl: firstSong.artworkUrl,
        releaseYear: '2024',
        songs: e.value,
      );
    }).toList();
  }

  static void _buildPlaylists() {
    if (allSongs.isEmpty) {
      featuredPlaylists = [];
      return;
    }

    final List<Playlist> list = [];

    // 1. Top Trending Hits Playlist
    list.add(Playlist(
      id: 'top_trending_hits',
      title: 'Top Trending Hits',
      creator: 'Muxiz Editorial',
      description: 'The most streamed tracks right now.',
      coverUrl: allSongs.first.artworkUrl,
      songs: allSongs.take(20).toList(),
    ));

    // 2. Dynamic Playlists from Top Artists (Extracted dynamically)
    for (int i = 0; i < popularArtists.length && i < 2; i++) {
      final a = popularArtists[i];
      if (a.topTracks.isNotEmpty) {
        list.add(Playlist(
          id: 'artist_mix_${a.id}',
          title: '${a.name} Spotlight',
          creator: 'Muxiz Curators',
          description: 'Best tracks and essential discography of ${a.name}.',
          coverUrl: a.imageUrl,
          songs: a.topTracks,
        ));
      }
    }

    // 3. Dynamic Playlists by Genres
    final Map<String, List<Song>> genreMap = {};
    for (final s in allSongs) {
      if (s.genre.isNotEmpty && s.genre != 'Music') {
        genreMap.putIfAbsent(s.genre, () => []).add(s);
      }
    }
    for (final entry in genreMap.entries.take(2)) {
      if (entry.value.isNotEmpty) {
        list.add(Playlist(
          id: 'genre_mix_${entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
          title: '${entry.key} Mix',
          creator: 'Muxiz Radio',
          description: 'Essential ${entry.key} anthems & moods.',
          coverUrl: entry.value.first.artworkUrl,
          songs: entry.value,
        ));
      }
    }

    featuredPlaylists = list;
  }

  static void addSong(Song song) {
    final key = _songDedupKey(song);
    if (!allSongs.any((s) => _songDedupKey(s) == key)) {
      allSongs.insert(0, song);
      _buildArtistsAndAlbums();
      _buildPlaylists();
      LocalStorageService.saveCatalogSongsLocally(allSongs);
      catalogNotifier.notify();
    }
  }
}
