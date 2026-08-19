import 'song.dart';

class Album {
  final String id;
  final String title;
  final String artist;
  final String artworkUrl;
  final String releaseYear;
  final List<Song> songs;

  const Album({
    required this.id,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    this.releaseYear = '2024',
    this.songs = const [],
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Album',
      artist: json['artist']?.toString() ?? json['artistName']?.toString() ?? 'Artist',
      artworkUrl: json['artwork']?.toString() ??
          json['artworkUrl']?.toString() ??
          '',
      releaseYear: json['releaseYear']?.toString() ?? '2024',
    );
  }
}
