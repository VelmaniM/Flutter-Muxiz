import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../audio/audio_manager.dart';
import '../network/api_client.dart';
import '../services/recommendation_service.dart';
import '../storage/download_manager.dart';
import '../storage/local_storage.dart';
import '../../shared/models/song.dart';
import '../../shared/models/playlist.dart';
import '../../shared/models/artist.dart';
import '../../shared/models/album.dart';
import '../data/mock_catalog.dart';
import '../../features/details/presentation/artist_detail_screen.dart';
import '../../features/details/presentation/playlist_detail_screen.dart';
import 'song_action_models.dart';

final songActionControllerProvider = Provider<SongActionController>((ref) {
  return SongActionController(ref);
});

class SongActionController {
  final Ref _ref;
  final Set<String> _pendingActions = {};

  SongActionController(this._ref);

  bool _acquireLock(String songId, SongActionType action) {
    final key = '$songId:${action.name}';
    if (_pendingActions.contains(key)) return false;
    _pendingActions.add(key);
    // Auto-release lock after 2 seconds safety window
    Timer(const Duration(seconds: 2), () {
      _pendingActions.remove(key);
    });
    return true;
  }

  void _releaseLock(String songId, SongActionType action) {
    final key = '$songId:${action.name}';
    _pendingActions.remove(key);
  }

  // --- Feedback Toast / SnackBar (Silenced per user requirement: No alert popups) ---
  void showFeedback(
    BuildContext context,
    String message, {
    bool isError = false,
    SnackBarAction? action,
  }) {
    // Silenced: Seamless instant action execution without intrusive snackbars/alerts
    return;
  }

  // --- 1. Play Next ---
  void playNext(BuildContext context, Song song) {
    if (!_acquireLock(song.id, SongActionType.playNext)) return;
    try {
      _ref.read(playerStateProvider.notifier).playNext(song);
      showFeedback(context, 'Playing "${song.title}" next');
    } catch (e) {
      showFeedback(context, 'Could not add to queue', isError: true);
    } finally {
      _releaseLock(song.id, SongActionType.playNext);
    }
  }

  // --- 2. Add to Queue ---
  void addToQueue(BuildContext context, Song song) {
    if (!_acquireLock(song.id, SongActionType.addToQueue)) return;
    try {
      _ref.read(playerStateProvider.notifier).addToQueue(song);
      showFeedback(context, 'Added "${song.title}" to queue');
    } catch (e) {
      showFeedback(context, 'Could not add to queue', isError: true);
    } finally {
      _releaseLock(song.id, SongActionType.addToQueue);
    }
  }



  // --- 4. Download / Remove Download ---
  Future<void> downloadOrRemove(BuildContext context, Song song) async {
    final downloadMgr = _ref.read(downloadManagerProvider);
    final isDownloaded = downloadMgr.isDownloaded(song.id) || song.isDownloaded;

    if (isDownloaded) {
      if (!_acquireLock(song.id, SongActionType.removeDownload)) return;
      try {
        await downloadMgr.deleteDownloadedSong(song.id);
        if (context.mounted) {
          showFeedback(context, 'Removed download for "${song.title}"');
        }
      } catch (e) {
        if (context.mounted) {
          showFeedback(context, 'Failed to remove download', isError: true);
        }
      } finally {
        _releaseLock(song.id, SongActionType.removeDownload);
      }
    } else {
      if (!_acquireLock(song.id, SongActionType.download)) return;
      try {
        showFeedback(context, 'Downloading "${song.title}"...');
        final success = await downloadMgr.downloadSong(song);
        if (success && context.mounted) {
          showFeedback(context, 'Downloaded "${song.title}" ✓');
        } else if (!success && context.mounted) {
          showFeedback(context, 'Download failed. Please check connection.', isError: true);
        }
      } catch (e) {
        if (context.mounted) {
          showFeedback(context, 'Download failed.', isError: true);
        }
      } finally {
        _releaseLock(song.id, SongActionType.download);
      }
    }
  }

  // --- 5. Remove from Playlist ---
  Future<void> removeFromPlaylist(BuildContext context, Song song, String playlistId, {String? playlistTitle}) async {
    try {
      await _ref.read(customPlaylistsProvider.notifier).removeSongFromPlaylist(playlistId, song.id);
      if (context.mounted) {
        showFeedback(context, 'Removed from ${playlistTitle ?? "playlist"}');
      }
    } catch (e) {
      if (context.mounted) {
        showFeedback(context, 'Could not remove song from playlist', isError: true);
      }
    }
  }

  // --- 6. Remove from Queue ---
  void removeFromQueue(BuildContext context, int index, Song song) {
    try {
      _ref.read(playerStateProvider.notifier).removeFromQueue(index);
      showFeedback(context, 'Removed "${song.title}" from queue');
    } catch (e) {
      showFeedback(context, 'Could not remove from queue', isError: true);
    }
  }

  // --- 7. Safe Share (No private Drive URLs exposed) ---
  void shareSong(BuildContext context, Song song) {
    final movie = song.movieName != null ? ' (${song.movieName})' : '';
    final text = '🎵 Listening to "${song.title}"$movie by ${song.artist} on Muxiz Music App!';
    Clipboard.setData(ClipboardData(text: text));
    showFeedback(context, 'Link & song details copied to clipboard!');
  }

  // --- 8. Navigate to Artist ---
  void goToArtist(BuildContext context, Song song) {
    final normalized = MockMusicCatalog.normalizeArtistName(song.artist);
    final existingArtist = MockMusicCatalog.popularArtists.firstWhere(
      (a) =>
          a.name.toLowerCase() == normalized.toLowerCase() ||
          a.name.toLowerCase() == song.artist.toLowerCase(),
      orElse: () => Artist(
        id: 'artist_${normalized.replaceAll(" ", "_").toLowerCase()}',
        name: normalized,
        imageUrl: MockMusicCatalog.artistPortraits[normalized.toLowerCase()] ?? song.artworkUrl,
        monthlyListeners: '2.5M',
        topTracks: MockMusicCatalog.getSongsForArtist(normalized),
      ),
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArtistDetailScreen(artist: existingArtist)),
    );
  }

  // --- 9. Navigate to Album ---
  void goToAlbum(BuildContext context, Song song) {
    final albumName = MockMusicCatalog.normalizeMovieOrAlbumName(song);
    final existingAlbum = MockMusicCatalog.topAlbums.firstWhere(
      (a) =>
          a.title.toLowerCase() == albumName.toLowerCase() ||
          a.title.toLowerCase() == song.album.toLowerCase(),
      orElse: () {
        final albumSongs = MockMusicCatalog.allSongs
            .where((s) =>
                MockMusicCatalog.normalizeMovieOrAlbumName(s).toLowerCase() ==
                albumName.toLowerCase())
            .toList();
        return Album(
          id: 'album_${albumName.replaceAll(" ", "_").toLowerCase()}',
          title: albumName,
          artist: song.artist,
          artworkUrl: song.artworkUrl,
          releaseYear: '2024',
          songs: albumSongs.isNotEmpty ? albumSongs : [song],
        );
      },
    );
    final albumPlaylist = Playlist(
      id: existingAlbum.id,
      title: existingAlbum.title,
      description: 'Album • ${existingAlbum.songs.length} songs',
      coverUrl: existingAlbum.artworkUrl,
      creator: existingAlbum.artist,
      songs: existingAlbum.songs.isNotEmpty ? existingAlbum.songs : [song],
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlist: albumPlaylist)),
    );
  }

  // --- 10. Show Song Details Sheet ---
  void showSongDetails(BuildContext context, Song song) {
    final durSec = song.duration;
    final durFormatted = '${durSec ~/ 60}:${(durSec % 60).toString().padLeft(2, '0')}';
    final downloadMgr = _ref.read(downloadManagerProvider);
    final isDownloaded = downloadMgr.isDownloaded(song.id) || song.isDownloaded;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Song Details',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildDetailRow('Title', song.title),
                _buildDetailRow('Artist', song.artist),
                _buildDetailRow('Album', song.album),
                if (song.movieName != null) _buildDetailRow('Movie', song.movieName!),
                _buildDetailRow('Duration', durFormatted),
                _buildDetailRow('Audio Quality', '320 kbps MP3 (HQ Audio)'),
                _buildDetailRow('Offline Available', isDownloaded ? 'Yes (Downloaded)' : 'Stream Only'),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 11. Permanent Delete from Server, Drive & Local Storage ---
  Future<void> deleteSongPermanently(BuildContext context, Song song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text(
              'Delete Song?',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${song.title}"?\n\nThis will completely remove the song from Google Drive, database, and all playlists.',
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text(
              'Delete Everywhere',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 1. If currently playing, stop/skip playback immediately
    final playerNotifier = _ref.read(playerStateProvider.notifier);
    final playerState = _ref.read(playerStateProvider);
    if (playerState.currentSong?.id == song.id) {
      playerNotifier.skipToNext();
      if (_ref.read(playerStateProvider).currentSong?.id == song.id) {
        playerNotifier.togglePlayPause();
      }
    }

    // 2. IMMEDIATE OPTIMISTIC REMOVAL (0ms UI latency!)
    MockMusicCatalog.removeSong(song.id);
    _ref.read(likedSongsProvider.notifier).refresh();
    _ref.read(homeFeedProvider.notifier).refreshFeed();

    // Show snappy UI confirmation toast
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF282828),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Deleted "${song.title}"',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Perform disk and cloud/DB deletion in non-blocking background queue
    Future.microtask(() async {
      try {
        await LocalStorageService.removeSongEverywhere(song.id);
        await _ref.read(apiClientProvider).deleteSong(song.id);
      } catch (e) {
        debugPrint('Error deleting song: $e');
      }
    });
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
