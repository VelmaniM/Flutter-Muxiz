import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../../shared/models/song.dart';
import '../data/mock_catalog.dart';

class RemoteAudioSource {
  static AudioSource create(Song song) {
    final resolvedUrl = MockMusicCatalog.resolveAudioUrl(song.audioUrl);
    final mediaItem = MediaItem(
      id: song.id,
      album: song.album,
      title: song.title,
      artist: song.artist,
      duration: Duration(seconds: song.duration),
      artUri: Uri.tryParse(song.artworkUrl),
      extras: {
        'isDownloaded': false,
        'audioUrl': resolvedUrl,
      },
    );

    return AudioSource.uri(
      Uri.parse(resolvedUrl),
      tag: mediaItem,
    );
  }
}
