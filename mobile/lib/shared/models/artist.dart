import 'song.dart';

class Artist {
  final String id;
  final String name;
  final String imageUrl;
  final String? bio;
  final String monthlyListeners;
  final bool isVerified;
  final List<Song> topTracks;

  const Artist({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.bio,
    this.monthlyListeners = '2.4M',
    this.isVerified = true,
    this.topTracks = const [],
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Artist',
      imageUrl: json['image']?.toString() ??
          json['imageUrl']?.toString() ??
          '',
      bio: json['bio']?.toString(),
      monthlyListeners: json['monthlyListeners']?.toString() ?? '1.8M',
      isVerified: json['isVerified'] ?? true,
    );
  }
}
