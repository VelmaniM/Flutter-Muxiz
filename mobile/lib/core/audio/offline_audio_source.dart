import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../../shared/models/song.dart';

class OfflineAudioSource {
  static bool isAvailable(Song song) {
    if (song.isDownloaded && song.localAudioPath != null && song.localAudioPath!.isNotEmpty) {
      final file = File(song.localAudioPath!);
      return file.existsSync();
    }
    return false;
  }

  static AudioSource create(Song song) {
    final mediaItem = MediaItem(
      id: song.id,
      album: song.album,
      title: song.title,
      artist: song.artist,
      duration: Duration(seconds: song.duration),
      artUri: song.localArtworkPath != null && File(song.localArtworkPath!).existsSync()
          ? Uri.file(song.localArtworkPath!)
          : Uri.tryParse(song.artworkUrl),
      extras: {
        'isDownloaded': true,
        'localAudioPath': song.localAudioPath,
      },
    );

    return AudioSource.file(
      song.localAudioPath!,
      tag: mediaItem,
    );
  }
}
