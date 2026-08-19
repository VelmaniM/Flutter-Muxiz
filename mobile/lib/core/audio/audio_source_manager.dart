import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../../shared/models/song.dart';
import 'offline_audio_source.dart';
import 'remote_audio_source.dart';

class AudioSourceManager {
  static AudioSource createAudioSource(Song song) {
    if (OfflineAudioSource.isAvailable(song)) {
      return OfflineAudioSource.create(song);
    }
    return RemoteAudioSource.create(song);
  }

  static ConcatenatingAudioSource createPlaylist(List<Song> songs) {
    final sources = songs.map(createAudioSource).toList();
    return ConcatenatingAudioSource(
      useLazyPreparation: true,
      children: sources,
    );
  }

  static MediaItem createMediaItem(Song song) {
    final isOffline = OfflineAudioSource.isAvailable(song);
    return MediaItem(
      id: song.id,
      album: song.album,
      title: song.title,
      artist: song.artist,
      duration: Duration(seconds: song.duration),
      artUri: isOffline && song.localArtworkPath != null
          ? Uri.file(song.localArtworkPath!)
          : Uri.tryParse(song.artworkUrl),
      extras: {
        'isDownloaded': isOffline,
        'genre': song.genre,
        'language': song.language,
      },
    );
  }
}
