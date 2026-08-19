import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../../shared/models/song.dart';

class RemoteAudioSource {
  static AudioSource create(Song song) {
    final mediaItem = MediaItem(
      id: song.id,
      album: song.album,
      title: song.title,
      artist: song.artist,
      duration: Duration(seconds: song.duration),
      artUri: Uri.tryParse(song.artworkUrl),
      extras: {
        'isDownloaded': false,
        'audioUrl': song.audioUrl,
      },
    );

    // ignore: deprecated_member_use, experimental_member_use
    return LockCachingAudioSource(
      Uri.parse(song.audioUrl),
      tag: mediaItem,
    );
  }
}
