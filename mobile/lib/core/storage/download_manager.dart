import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/song.dart';
import 'local_storage.dart';

enum DownloadStatus {
  idle,
  downloading,
  downloaded,
  failed,
}

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  return DownloadManager();
});

final downloadProgressProvider = StateProvider.family<double, String>((ref, songId) {
  return 0.0;
});

class DownloadManager {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  final Map<String, CancelToken> _cancelTokens = {};

  Future<String> _getAudioDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${docDir.path}/muxiz_music/audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir.path;
  }

  Future<String> _getArtworkDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final artDir = Directory('${docDir.path}/muxiz_music/artwork');
    if (!await artDir.exists()) {
      await artDir.create(recursive: true);
    }
    return artDir.path;
  }

  Future<bool> downloadSong(
    Song song, {
    Function(double progress)? onProgress,
  }) async {
    final cancelToken = CancelToken();
    _cancelTokens[song.id] = cancelToken;

    try {
      final audioDir = await _getAudioDirectory();
      final artDir = await _getArtworkDirectory();

      final cleanId = song.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final audioPath = '$audioDir/$cleanId.mp3';
      final artworkPath = '$artDir/$cleanId.jpg';

      // 1. Download Audio File into app-private storage
      await _dio.download(
        song.audioUrl,
        audioPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            final progress = (received / total) * 0.9;
            onProgress(progress.clamp(0.0, 0.9));
          }
        },
      );

      // 2. Download Artwork File
      try {
        if (song.artworkUrl.isNotEmpty) {
          await _dio.download(song.artworkUrl, artworkPath, cancelToken: cancelToken);
        }
      } catch (_) {}

      // 3. Complete progress
      onProgress?.call(1.0);

      // 4. Save metadata to LocalStorage
      final downloadedSong = song.copyWith(
        isDownloaded: true,
        localAudioPath: audioPath,
        localArtworkPath: artworkPath,
      );

      await LocalStorageService.saveDownloadedSong(downloadedSong);
      _cancelTokens.remove(song.id);
      return true;
    } catch (e) {
      _cancelTokens.remove(song.id);
      return false;
    }
  }

  bool isDownloaded(String songId) {
    return LocalStorageService.getDownloadedSongs().any((s) => s.id == songId);
  }

  List<Song> getDownloadedSongs() {
    return LocalStorageService.getDownloadedSongs();
  }

  void cancelDownload(String songId) {
    if (_cancelTokens.containsKey(songId)) {
      _cancelTokens[songId]?.cancel('Download cancelled by user');
      _cancelTokens.remove(songId);
    }
  }

  Future<void> deleteDownloadedSong(String songId) async {
    cancelDownload(songId);
    try {
      final audioDir = await _getAudioDirectory();
      final artDir = await _getArtworkDirectory();
      final cleanId = songId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

      final audioFile = File('$audioDir/$cleanId.mp3');
      final artFile = File('$artDir/$cleanId.jpg');

      if (await audioFile.exists()) await audioFile.delete();
      if (await artFile.exists()) await artFile.delete();

      await LocalStorageService.removeDownloadedSong(songId);
    } catch (_) {}
  }

  Future<int> getTotalDownloadSize() async {
    try {
      final audioDir = Directory(await _getAudioDirectory());
      int totalSize = 0;
      if (await audioDir.exists()) {
        await for (final file in audioDir.list(recursive: true, followLinks: false)) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      }
      return totalSize;
    } catch (_) {
      return 0;
    }
  }

  String formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}
