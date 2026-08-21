import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/constants.dart';
import '../../shared/models/song.dart';
import '../../shared/models/playlist.dart';
import '../data/mock_catalog.dart';
import '../storage/local_storage.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

class ApiClient {
  final Dio _dio;

  ApiClient({String? baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? AppConstants.defaultApiBaseUrl,
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = LocalStorageService.getAuthToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['x-user-id'] = LocalStorageService.getUserId();
          return handler.next(options);
        },
      ),
    );
  }

  // --- Authentication ---
  Future<({Map<String, dynamic>? user, String? token, String? error, bool isNewUser})> googleAuth({
    required String email,
    String? displayName,
    String? avatar,
    String? googleId,
  }) async {
    for (final baseUrl in [AppConstants.defaultApiBaseUrl, ...AppConstants.fallbackApiBaseUrls]) {
      try {
        final res = await Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
        )).post(
          '$baseUrl/auth/google',
          data: {
            'email': email.trim().toLowerCase(),
            'displayName': displayName,
            'avatar': avatar,
            'googleId': googleId,
          },
        );
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = res.data as Map<String, dynamic>;
          final token = data['token']?.toString();
          final user = data['user'] as Map<String, dynamic>?;
          final isNewUser = data['isNewUser'] == true;
          if (token != null) {
            await LocalStorageService.setAuthToken(token);
          }
          if (user != null) {
            await LocalStorageService.setUserData(user);
            if (user['displayName'] != null && user['displayName'].toString().trim().isNotEmpty) {
              final localName = LocalStorageService.getUserName();
              if (localName.isEmpty) {
                await LocalStorageService.saveUserName(user['displayName'].toString());
              }
            }
            if (user['avatar'] != null && user['avatar'].toString().trim().isNotEmpty) {
              final localAvatar = LocalStorageService.getUserAvatar();
              if (localAvatar == null || localAvatar.isEmpty) {
                await LocalStorageService.saveUserAvatar(user['avatar'].toString());
              }
            }
          }
          return (user: user, token: token, error: null, isNewUser: isNewUser);
        }
      } on DioException catch (dioErr) {
        final errMsg = dioErr.response?.data?['error']?.toString();
        if (errMsg != null) {
          return (user: null, token: null, error: errMsg, isNewUser: false);
        }
      } catch (_) {}
    }
    return (user: null, token: null, error: 'Could not connect to SQL authentication server.', isNewUser: false);
  }

  Future<({Map<String, dynamic>? user, String? token, String? error})> login({
    required String email,
    required String password,
  }) async {
    for (final baseUrl in [AppConstants.defaultApiBaseUrl, ...AppConstants.fallbackApiBaseUrls]) {
      try {
        final res = await Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
        )).post(
          '$baseUrl/auth/login',
          data: {'email': email.trim().toLowerCase(), 'password': password},
        );
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = res.data as Map<String, dynamic>;
          final token = data['token']?.toString();
          final user = data['user'] as Map<String, dynamic>?;
          if (token != null) {
            await LocalStorageService.setAuthToken(token);
          }
          if (user != null) {
            await LocalStorageService.setUserData(user);
            if (user['displayName'] != null && user['displayName'].toString().trim().isNotEmpty) {
              final localName = LocalStorageService.getUserName();
              if (localName.isEmpty) {
                await LocalStorageService.saveUserName(user['displayName'].toString());
              }
            }
            if (user['avatar'] != null && user['avatar'].toString().trim().isNotEmpty) {
              final localAvatar = LocalStorageService.getUserAvatar();
              if (localAvatar == null || localAvatar.isEmpty) {
                await LocalStorageService.saveUserAvatar(user['avatar'].toString());
              }
            }
          }
          return (user: user, token: token, error: null);
        }
      } on DioException catch (dioErr) {
        final errMsg = dioErr.response?.data?['error']?.toString();
        if (errMsg != null) {
          return (user: null, token: null, error: errMsg);
        }
      } catch (_) {}
    }
    return (user: null, token: null, error: 'Could not connect to SQL authentication server.');
  }

  Future<({Map<String, dynamic>? user, String? token, String? error})> register({
    required String email,
    required String password,
    String? displayName,
    String? avatar,
  }) async {
    for (final baseUrl in [AppConstants.defaultApiBaseUrl, ...AppConstants.fallbackApiBaseUrls]) {
      try {
        final res = await Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
        )).post(
          '$baseUrl/auth/register',
          data: {
            'email': email.trim().toLowerCase(),
            'password': password,
            'displayName': displayName,
            'avatar': avatar,
          },
        );
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = res.data as Map<String, dynamic>;
          final token = data['token']?.toString();
          final user = data['user'] as Map<String, dynamic>?;
          if (token != null) {
            await LocalStorageService.setAuthToken(token);
          }
          if (user != null) {
            await LocalStorageService.setUserData(user);
            if (user['displayName'] != null && user['displayName'].toString().trim().isNotEmpty) {
              final localName = LocalStorageService.getUserName();
              if (localName.isEmpty) {
                await LocalStorageService.saveUserName(user['displayName'].toString());
              }
            }
            if (user['avatar'] != null && user['avatar'].toString().trim().isNotEmpty) {
              final localAvatar = LocalStorageService.getUserAvatar();
              if (localAvatar == null || localAvatar.isEmpty) {
                await LocalStorageService.saveUserAvatar(user['avatar'].toString());
              }
            }
          }
          return (user: user, token: token, error: null);
        }
      } on DioException catch (dioErr) {
        final errMsg = dioErr.response?.data?['error']?.toString();
        if (errMsg != null) {
          return (user: null, token: null, error: errMsg);
        }
      } catch (_) {}
    }
    return (user: null, token: null, error: 'Could not connect to SQL authentication server.');
  }

  Future<({Map<String, dynamic>? user, String? token})?> guestLogin({String? deviceId}) async {
    for (final baseUrl in [AppConstants.defaultApiBaseUrl, ...AppConstants.fallbackApiBaseUrls]) {
      try {
        final res = await Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        )).post(
          '$baseUrl/auth/guest',
          data: {'deviceId': deviceId ?? 'mobile_device'},
        );
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = res.data as Map<String, dynamic>;
          final token = data['token']?.toString();
          final user = data['user'] as Map<String, dynamic>?;
          if (token != null) {
            await LocalStorageService.setAuthToken(token);
          }
          if (user != null) {
            await LocalStorageService.setUserData(user);
          }
          return (user: user, token: token);
        }
      } catch (_) {}
    }
    return null;
  }

  Future<({Map<String, dynamic>? user, String? error})> updateProfile({
    required String userId,
    String? displayName,
    String? avatar,
  }) async {
    for (final baseUrl in [AppConstants.defaultApiBaseUrl, ...AppConstants.fallbackApiBaseUrls]) {
      try {
        final res = await Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        )).post(
          '$baseUrl/auth/profile',
          data: {
            'userId': userId,
            if (displayName != null) 'displayName': displayName,
            if (avatar != null) 'avatar': avatar,
          },
        );
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data as Map<String, dynamic>;
          final user = data['user'] as Map<String, dynamic>?;
          if (user != null) {
            await LocalStorageService.setUserData(user);
            if (user['displayName'] != null) {
              await LocalStorageService.saveUserName(user['displayName'].toString());
            }
            if (user['avatar'] != null) {
              await LocalStorageService.saveUserAvatar(user['avatar'].toString());
            }
          }
          return (user: user, error: null);
        }
      } catch (_) {}
    }
    return (user: null, error: 'Failed to update profile on backend');
  }

  // --- Songs & Search ---
  Future<List<Song>> fetchSongs({int page = 1, int limit = 50, String? genre}) async {
    for (final baseUrl in [AppConstants.defaultApiBaseUrl, ...AppConstants.fallbackApiBaseUrls, 'https://muxiz.vercel.app/api/drive']) {
      try {
        final endpoint = baseUrl.endsWith('/drive') ? '$baseUrl/songs' : '$baseUrl/songs';
        final response = await Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        )).get(
          endpoint,
          queryParameters: {
            'page': page,
            'limit': limit,
            if (genre != null) 'genre': genre,
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          final rawData = response.data;
          final List<dynamic>? data = (rawData is Map ? (rawData['data'] ?? rawData['songs']) : rawData) as List<dynamic>?;
          if (data != null && data.isNotEmpty) {
            return data.map((json) => Song.fromJson(json as Map<String, dynamic>)).toList();
          }
        }
      } catch (_) {}
    }

    return MockMusicCatalog.allSongs;
  }

  Future<bool> deleteSong(String songId) async {
    bool deleted = false;
    for (final baseUrl in [AppConstants.defaultApiBaseUrl, ...AppConstants.fallbackApiBaseUrls]) {
      try {
        final res = await Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        )).delete('$baseUrl/songs/$songId');
        if (res.statusCode == 200 || res.statusCode == 204) {
          deleted = true;
          break;
        }
      } catch (_) {}
    }
    return deleted;
  }

  Future<List<Song>> searchSongs(String query) async {
    if (query.trim().isEmpty) return [];

    for (final baseUrl in [AppConstants.defaultApiBaseUrl, ...AppConstants.fallbackApiBaseUrls]) {
      try {
        final response = await Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        )).get(
          '$baseUrl/search',
          queryParameters: {'q': query},
        );

        if (response.statusCode == 200 && response.data != null) {
          final songs = response.data['songs'] as List<dynamic>?;
          if (songs != null && songs.isNotEmpty) {
            return songs.map((json) => Song.fromJson(json as Map<String, dynamic>)).toList();
          }
        }
      } catch (_) {}
    }

    // Fallback local search
    final q = query.toLowerCase();
    return MockMusicCatalog.allSongs
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            s.artist.toLowerCase().contains(q) ||
            s.album.toLowerCase().contains(q) ||
            (s.movieName?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  // --- Favorites & Likes ---
  Future<({bool isFavorite, int count})?> toggleLike(String songId, {String userId = 'listener-001'}) async {
    try {
      final response = await _dio.post(
        '/songs/$songId/like',
        data: {'userId': userId},
        options: Options(headers: {'x-user-id': userId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final isFav = response.data['isFavorite'] as bool? ?? true;
        final count = response.data['count'] as int? ?? 1;
        return (isFavorite: isFav, count: count);
      }
    } catch (_) {}
    return null;
  }

  Future<List<Song>> fetchFavorites({String userId = 'listener-001'}) async {
    try {
      final response = await _dio.get(
        '/users/favorites',
        options: Options(headers: {'x-user-id': userId}),
      );

      if (response.statusCode == 200 && response.data is List) {
        final list = response.data as List<dynamic>;
        return list.map((item) => Song.fromJson(item as Map<String, dynamic>).copyWith(isFavorite: true)).toList();
      }
    } catch (_) {}
    return [];
  }

  // --- Playlists ---
  Future<List<Playlist>> fetchPlaylists({String userId = 'listener-001'}) async {
    try {
      final response = await _dio.get(
        '/playlists',
        options: Options(headers: {'x-user-id': userId}),
      );

      if (response.statusCode == 200 && response.data is List) {
        final list = response.data as List<dynamic>;
        return list.map((item) {
          final pMap = item as Map<String, dynamic>;
          final songsRaw = pMap['songs'] as List<dynamic>? ?? [];
          final songs = songsRaw.map((ps) {
            if (ps is Map<String, dynamic> && ps['song'] != null) {
              return Song.fromJson(ps['song'] as Map<String, dynamic>);
            }
            return null;
          }).whereType<Song>().toList();

          return Playlist(
            id: pMap['id']?.toString() ?? 'pl_${DateTime.now().millisecondsSinceEpoch}',
            title: pMap['title']?.toString() ?? 'Playlist',
            description: pMap['description']?.toString() ?? 'Custom Playlist',
            coverUrl: pMap['cover']?.toString() ?? '',
            creator: pMap['userId']?.toString() ?? 'You',
            songs: songs,
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Playlist?> createPlaylist(
    String title, {
    String? description,
    String? cover,
    String? initialSongId,
    String userId = 'listener-001',
  }) async {
    try {
      final response = await _dio.post(
        '/playlists',
        data: {
          'title': title,
          'description': description ?? 'Custom Playlist',
          'cover': cover,
          'initialSongId': initialSongId,
          'userId': userId,
        },
        options: Options(headers: {'x-user-id': userId}),
      );

      if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
        final pMap = response.data as Map<String, dynamic>;
        final songsRaw = pMap['songs'] as List<dynamic>? ?? [];
        final songs = songsRaw.map((ps) {
          if (ps is Map<String, dynamic> && ps['song'] != null) {
            return Song.fromJson(ps['song'] as Map<String, dynamic>);
          }
          return null;
        }).whereType<Song>().toList();

        return Playlist(
          id: pMap['id']?.toString() ?? 'pl_${DateTime.now().millisecondsSinceEpoch}',
          title: pMap['title']?.toString() ?? title,
          description: pMap['description']?.toString() ?? 'Custom Playlist',
          coverUrl: pMap['cover']?.toString() ?? (cover ?? ''),
          creator: pMap['userId']?.toString() ?? 'You',
          songs: songs,
        );
      }
    } catch (_) {}
    return null;
  }

  Future<({bool success, bool added, bool alreadyExists})> addSongToPlaylist(
    String playlistId,
    String songId,
  ) async {
    try {
      final response = await _dio.post(
        '/playlists/$playlistId/songs',
        data: {'songId': songId},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final added = response.data['added'] as bool? ?? true;
        final alreadyExists = response.data['alreadyExists'] as bool? ?? false;
        return (success: true, added: added, alreadyExists: alreadyExists);
      }
    } catch (_) {}
    return (success: false, added: false, alreadyExists: false);
  }

  Future<bool> removeSongFromPlaylist(String playlistId, String songId) async {
    try {
      final response = await _dio.delete('/playlists/$playlistId/songs/$songId');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deletePlaylist(String playlistId) async {
    try {
      final response = await _dio.delete('/playlists/$playlistId');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  // --- Recently Played & History ---
  Future<void> recordRecentlyPlayed(String songId, {String userId = 'listener-001'}) async {
    try {
      await _dio.post(
        '/users/recently-played/$songId',
        options: Options(headers: {'x-user-id': userId}),
      );
    } catch (_) {}
  }

  Future<void> recordHistory(String songId, int durationSec, {String userId = 'listener-001'}) async {
    try {
      await _dio.post(
        '/users/history',
        data: {'songId': songId, 'duration': durationSec},
        options: Options(headers: {'x-user-id': userId}),
      );
    } catch (_) {}
  }

  // --- Downloads Sync ---
  Future<void> recordDownload(String songId, {String userId = 'listener-001', int fileSize = 0}) async {
    try {
      await _dio.post(
        '/users/downloads',
        data: {'songId': songId, 'fileSize': fileSize, 'deviceId': 'ios-device'},
        options: Options(headers: {'x-user-id': userId}),
      );
    } catch (_) {}
  }

  Future<void> removeDownload(String songId, {String userId = 'listener-001'}) async {
    try {
      await _dio.delete(
        '/users/downloads/$songId',
        options: Options(headers: {'x-user-id': userId}),
      );
    } catch (_) {}
  }

  // --- Gemini AI Tamil Music Trend Insights ---
  Future<Map<String, dynamic>?> fetchTrendingInsights() async {
    try {
      final response = await _dio.get('/recommendations/trending');
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}

