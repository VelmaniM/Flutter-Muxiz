import 'song.dart';

class Playlist {
  final String id;
  final String title;
  final String description;
  final String coverUrl;
  final String creator;
  final bool isUserCreated;
  final List<Song> songs;

  const Playlist({
    required this.id,
    required this.title,
    this.description = '',
    required this.coverUrl,
    this.creator = 'Muxiz',
    this.isUserCreated = false,
    this.songs = const [],
  });

  Playlist copyWith({
    String? id,
    String? title,
    String? description,
    String? coverUrl,
    String? creator,
    bool? isUserCreated,
    List<Song>? songs,
  }) {
    return Playlist(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      creator: creator ?? this.creator,
      isUserCreated: isUserCreated ?? this.isUserCreated,
      songs: songs ?? this.songs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'coverUrl': coverUrl,
      'creator': creator,
      'isUserCreated': isUserCreated,
      'songs': songs.map((s) => s.toJson()).toList(),
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Playlist',
      description: json['description']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ??
          json['cover']?.toString() ??
          '',
      creator: json['creator']?.toString() ?? 'Muxiz',
      isUserCreated: json['isUserCreated'] == true,
      songs: (json['songs'] as List<dynamic>?)
              ?.map((s) => Song.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
