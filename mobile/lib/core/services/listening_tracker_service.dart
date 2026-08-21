import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/song.dart';
import '../../shared/models/listening_activity.dart';
import '../../shared/models/continue_listening_item.dart';
import '../storage/local_storage.dart';

final listeningTrackerServiceProvider = Provider<ListeningTrackerService>((ref) {
  return ListeningTrackerService.instance;
});

class ListeningTrackerService {
  static final ListeningTrackerService instance = ListeningTrackerService._internal();
  ListeningTrackerService._internal();

  String? _currentTrackingSongId;
  String? _currentPlaylistContextId;
  int _lastTrackedPositionSec = 0;
  int _accumulatedSecondsThisSession = 0;
  bool _meaningfulListenRecordedForCurrentTrack = false;
  DateTime? _sessionStartTime;
  DateTime _lastContinueListeningSave = DateTime.fromMillisecondsSinceEpoch(0);

  final _activityStreamController = StreamController<ListeningActivityRecord>.broadcast();
  Stream<ListeningActivityRecord> get onActivityRecorded => _activityStreamController.stream;

  /// Resets internal session tracker (for testing or user switch)
  void resetSession() {
    _currentTrackingSongId = null;
    _currentPlaylistContextId = null;
    _lastTrackedPositionSec = 0;
    _accumulatedSecondsThisSession = 0;
    _meaningfulListenRecordedForCurrentTrack = false;
    _sessionStartTime = null;
    _lastContinueListeningSave = DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Starts tracking a new song playback session
  void onSongStarted(Song song, {String? playlistContextId, bool force = false}) {
    if (!force && _currentTrackingSongId == song.id && _sessionStartTime != null) {
      // Same song continued
      return;
    }

    // Flush any pending accumulated duration for the previous song
    _flushAccumulatedDuration();

    _currentTrackingSongId = song.id;
    _currentPlaylistContextId = playlistContextId;
    _lastTrackedPositionSec = 0;
    _accumulatedSecondsThisSession = 0;
    _meaningfulListenRecordedForCurrentTrack = false;
    _sessionStartTime = DateTime.now();
    _lastContinueListeningSave = DateTime.fromMillisecondsSinceEpoch(0);

    debugPrint('[HOME_ALGO] Started tracking playback: "${song.title}" (${song.id})');
  }

  /// Called periodically by AudioController position stream
  void onPositionUpdated(Song song, Duration position, Duration duration) {
    if (_currentTrackingSongId != song.id) {
      onSongStarted(song);
    }

    final posSec = position.inSeconds;
    final durSec = duration.inSeconds > 0 ? duration.inSeconds : song.duration;

    // Track progression delta
    if (posSec > _lastTrackedPositionSec) {
      final delta = posSec - _lastTrackedPositionSec;
      _accumulatedSecondsThisSession += delta;
    }
    _lastTrackedPositionSec = posSec;

    // Continue Listening lifecycle:
    // If track is in progress (>= 15s and < 90% completed), record for Continue Listening
    final now = DateTime.now();
    if (posSec >= 15 && posSec < (durSec * 0.90)) {
      if (now.difference(_lastContinueListeningSave).inSeconds >= 3) {
        _lastContinueListeningSave = now;
        LocalStorageService.saveContinueListeningItem(
          ContinueListeningItem(
            song: song,
            progressSeconds: posSec,
            totalDurationSeconds: durSec,
            lastListenedAt: now,
            playlistContextId: _currentPlaylistContextId,
          ),
        );
      }
    } else if (posSec >= (durSec * 0.90) && durSec > 0) {
      // Track completed: safely dismiss from Continue Listening shelf
      LocalStorageService.removeContinueListeningItem(song.id);
    }

    // Check meaningful listening threshold:
    // 1. Listened for at least 30 seconds OR
    // 2. Listened for at least 25% of total duration OR
    // 3. For short tracks (< 30s), reached within 2s of end
    if (!_meaningfulListenRecordedForCurrentTrack) {
      final bool isMeaningful = _accumulatedSecondsThisSession >= 30 ||
          (durSec > 0 && _accumulatedSecondsThisSession >= (durSec * 0.25).round()) ||
          (durSec > 0 && durSec < 30 && _accumulatedSecondsThisSession >= durSec - 2);

      if (isMeaningful) {
        _meaningfulListenRecordedForCurrentTrack = true;
        _recordMeaningfulListen(song, durSec);
      }
    }
  }

  /// Records the meaningful listen event across content hierarchy (Song, Album, Artist, Playlist)
  void _recordMeaningfulListen(Song song, int durationSec) {
    debugPrint('[HOME_ALGO] Listening event recorded: "${song.title}" (Duration: $_accumulatedSecondsThisSession s)');
    final now = DateTime.now();

    // 1. Record Song Activity
    final songRecord = _buildUpdatedRecord(
      contentId: song.id,
      contentType: QuickAccessContentType.song,
      title: song.title,
      subtitle: song.artist,
      imageUrl: song.artworkUrl,
      now: now,
      additionalDuration: _accumulatedSecondsThisSession,
      parentAlbumId: song.movieName ?? song.album,
      parentPlaylistId: _currentPlaylistContextId,
      artistId: song.artist,
    );
    LocalStorageService.saveListeningActivity(songRecord);
    _activityStreamController.add(songRecord);

    // 2. Record Parent Album Activity (if available)
    final albumTitle = (song.movieName ?? song.album).trim();
    if (albumTitle.isNotEmpty && albumTitle.toLowerCase() != 'single') {
      final albumRecord = _buildUpdatedRecord(
        contentId: 'album_${albumTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}',
        contentType: QuickAccessContentType.album,
        title: albumTitle,
        subtitle: 'Album • ${song.artist}',
        imageUrl: song.artworkUrl,
        now: now,
        additionalDuration: _accumulatedSecondsThisSession,
        artistId: song.artist,
      );
      LocalStorageService.saveListeningActivity(albumRecord);
    }

    // 3. Record Artist Activity
    final artistName = song.artist.trim();
    if (artistName.isNotEmpty && artistName.toLowerCase() != 'unknown artist') {
      final artistRecord = _buildUpdatedRecord(
        contentId: 'artist_${artistName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}',
        contentType: QuickAccessContentType.artist,
        title: artistName,
        subtitle: 'Artist',
        imageUrl: song.artworkUrl,
        now: now,
        additionalDuration: _accumulatedSecondsThisSession,
      );
      LocalStorageService.saveListeningActivity(artistRecord);
    }

    // 4. Record Playlist Activity (if active in playlist context)
    if (_currentPlaylistContextId != null && _currentPlaylistContextId!.isNotEmpty) {
      final playlist = LocalStorageService.getCustomPlaylists()
          .where((p) => p.id == _currentPlaylistContextId)
          .firstOrNull;
      if (playlist != null) {
        final playlistRecord = _buildUpdatedRecord(
          contentId: 'playlist_${playlist.id}',
          contentType: QuickAccessContentType.playlist,
          title: playlist.title,
          subtitle: 'Playlist',
          imageUrl: playlist.coverUrl.isNotEmpty ? playlist.coverUrl : song.artworkUrl,
          now: now,
          additionalDuration: _accumulatedSecondsThisSession,
        );
        LocalStorageService.saveListeningActivity(playlistRecord);
      }
    }
  }

  ListeningActivityRecord _buildUpdatedRecord({
    required String contentId,
    required QuickAccessContentType contentType,
    required String title,
    required String subtitle,
    required String imageUrl,
    required DateTime now,
    required int additionalDuration,
    String? parentAlbumId,
    String? parentPlaylistId,
    String? artistId,
  }) {
    final existing = LocalStorageService.getListeningActivity(contentId);
    if (existing != null) {
      // Repeat engagement check: if played again within 48h, increment repeat score
      final isRepeatEngagement = now.difference(existing.lastPlayedAt).inHours < 48;
      return existing.copyWith(
        title: title,
        subtitle: subtitle,
        imageUrl: imageUrl.isNotEmpty ? imageUrl : existing.imageUrl,
        lastPlayedAt: now,
        playCount: existing.playCount + 1,
        accumulatedListenDurationSec: existing.accumulatedListenDurationSec + additionalDuration,
        parentAlbumId: parentAlbumId ?? existing.parentAlbumId,
        parentPlaylistId: parentPlaylistId ?? existing.parentPlaylistId,
        artistId: artistId ?? existing.artistId,
        repeatEngagementCount: existing.repeatEngagementCount + (isRepeatEngagement ? 1 : 0),
      );
    } else {
      return ListeningActivityRecord(
        contentId: contentId,
        contentType: contentType,
        title: title,
        subtitle: subtitle,
        imageUrl: imageUrl,
        lastPlayedAt: now,
        playCount: 1,
        accumulatedListenDurationSec: additionalDuration,
        parentAlbumId: parentAlbumId,
        parentPlaylistId: parentPlaylistId,
        artistId: artistId,
        repeatEngagementCount: 0,
        explicitInteractions: 0,
      );
    }
  }

  /// Explicit interaction tracking (e.g. Liked or added to playlist)
  void recordExplicitInteraction(String contentId, QuickAccessContentType type, {int boost = 1}) {
    final existing = LocalStorageService.getListeningActivity(contentId);
    final now = DateTime.now();
    if (existing != null) {
      final updated = existing.copyWith(
        explicitInteractions: existing.explicitInteractions + boost,
        lastPlayedAt: now,
      );
      LocalStorageService.saveListeningActivity(updated);
      _activityStreamController.add(updated);
    } else {
      final created = ListeningActivityRecord(
        contentId: contentId,
        contentType: type,
        title: contentId,
        subtitle: '',
        imageUrl: '',
        lastPlayedAt: now,
        playCount: 0,
        accumulatedListenDurationSec: 0,
        repeatEngagementCount: 0,
        explicitInteractions: boost,
      );
      LocalStorageService.saveListeningActivity(created);
      _activityStreamController.add(created);
    }
  }

  /// Fast Local Signal for Content Opens (Album, Playlist, Artist)
  void recordFastLocalOpen(
    String contentId,
    String title,
    QuickAccessContentType type,
    String imageUrl, {
    String subtitle = '',
  }) {
    final now = DateTime.now();
    final existing = LocalStorageService.getListeningActivity(contentId);
    if (existing != null) {
      final updated = existing.copyWith(
        lastPlayedAt: now,
        playCount: existing.playCount + 1,
        title: title,
        subtitle: subtitle.isNotEmpty ? subtitle : existing.subtitle,
        imageUrl: imageUrl.isNotEmpty ? imageUrl : existing.imageUrl,
      );
      LocalStorageService.saveListeningActivity(updated);
      _activityStreamController.add(updated);
    } else {
      final created = ListeningActivityRecord(
        contentId: contentId,
        contentType: type,
        title: title,
        subtitle: subtitle,
        imageUrl: imageUrl,
        lastPlayedAt: now,
        playCount: 1,
        accumulatedListenDurationSec: 0,
        repeatEngagementCount: 0,
        explicitInteractions: 1,
      );
      LocalStorageService.saveListeningActivity(created);
      _activityStreamController.add(created);
    }
  }

  void _flushAccumulatedDuration() {
    // Reset temporary session counters
    _accumulatedSecondsThisSession = 0;
    _sessionStartTime = null;
  }
}
