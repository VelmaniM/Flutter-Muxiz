class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? movieName;
  final String artworkUrl;
  final String audioUrl;
  final int duration; // in seconds
  final String genre;
  final String language;
  final List<String> lyrics;
  final List<String> gradient;
  final String? driveFileId;
  final String? artworkFileId;
  final bool isFavorite;
  final bool isDownloaded;
  final String? localAudioPath;
  final String? localArtworkPath;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    this.album = 'Single',
    this.movieName,
    required this.artworkUrl,
    required this.audioUrl,
    this.duration = 180,
    this.genre = 'Music',
    this.language = 'Tamil',
    this.lyrics = const [],
    this.gradient = const ['#1DB954', '#0B0C10'],
    this.driveFileId,
    this.artworkFileId,
    this.isFavorite = false,
    this.isDownloaded = false,
    this.localAudioPath,
    this.localArtworkPath,
  });

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? movieName,
    String? artworkUrl,
    String? audioUrl,
    int? duration,
    String? genre,
    String? language,
    List<String>? lyrics,
    List<String>? gradient,
    String? driveFileId,
    String? artworkFileId,
    bool? isFavorite,
    bool? isDownloaded,
    String? localAudioPath,
    String? localArtworkPath,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      movieName: movieName ?? this.movieName,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      duration: duration ?? this.duration,
      genre: genre ?? this.genre,
      language: language ?? this.language,
      lyrics: lyrics ?? this.lyrics,
      gradient: gradient ?? this.gradient,
      driveFileId: driveFileId ?? this.driveFileId,
      artworkFileId: artworkFileId ?? this.artworkFileId,
      isFavorite: isFavorite ?? this.isFavorite,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localAudioPath: localAudioPath ?? this.localAudioPath,
      localArtworkPath: localArtworkPath ?? this.localArtworkPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'movieName': movieName,
      'artworkUrl': artworkUrl,
      'audioUrl': audioUrl,
      'duration': duration,
      'genre': genre,
      'language': language,
      'lyrics': lyrics,
      'gradient': gradient,
      'driveFileId': driveFileId,
      'artworkFileId': artworkFileId,
      'isFavorite': isFavorite,
      'isDownloaded': isDownloaded,
      'localAudioPath': localAudioPath,
      'localArtworkPath': localArtworkPath,
    };
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Track',
      artist: json['artist']?.toString() ?? json['artistName']?.toString() ?? 'Unknown Artist',
      album: json['album']?.toString() ?? json['albumName']?.toString() ?? 'Single',
      movieName: json['movieName']?.toString() ?? json['movie']?.toString(),
      artworkUrl: json['artworkUrl']?.toString() ??
          json['artwork']?.toString() ??
          '',
      audioUrl: json['audioUrl']?.toString() ?? '',
      duration: json['duration'] is int ? json['duration'] : int.tryParse(json['duration']?.toString() ?? '180') ?? 180,
      genre: json['genre']?.toString() ?? 'Music',
      language: json['language']?.toString() ?? 'Tamil',
      lyrics: (json['lyrics'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      gradient: (json['gradient'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['#1DB954', '#0B0C10'],
      driveFileId: json['driveFileId']?.toString(),
      artworkFileId: json['artworkFileId']?.toString(),
      isFavorite: json['isFavorite'] == true,
      isDownloaded: json['isDownloaded'] == true,
      localAudioPath: json['localAudioPath']?.toString(),
      localArtworkPath: json['localArtworkPath']?.toString(),
    );
  }

  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Song && runtimeType == other.runtimeType && id == other.id);

  @override
  int get hashCode => id.hashCode;
}
