import 'dart:convert';

/// Represents the type of content tracked for Quick Access
enum QuickAccessContentType {
  song,
  album,
  playlist,
  artist,
}

/// A structured listening activity record tracked per content item
class ListeningActivityRecord {
  final String contentId;
  final QuickAccessContentType contentType;
  final String title;
  final String subtitle;
  final String imageUrl;
  final DateTime lastPlayedAt;
  final int playCount;
  final int accumulatedListenDurationSec;
  final String? parentAlbumId;
  final String? parentPlaylistId;
  final String? artistId;
  final int repeatEngagementCount;
  final int explicitInteractions;

  const ListeningActivityRecord({
    required this.contentId,
    required this.contentType,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.lastPlayedAt,
    this.playCount = 1,
    this.accumulatedListenDurationSec = 0,
    this.parentAlbumId,
    this.parentPlaylistId,
    this.artistId,
    this.repeatEngagementCount = 0,
    this.explicitInteractions = 0,
  });

  ListeningActivityRecord copyWith({
    String? contentId,
    QuickAccessContentType? contentType,
    String? title,
    String? subtitle,
    String? imageUrl,
    DateTime? lastPlayedAt,
    int? playCount,
    int? accumulatedListenDurationSec,
    String? parentAlbumId,
    String? parentPlaylistId,
    String? artistId,
    int? repeatEngagementCount,
    int? explicitInteractions,
  }) {
    return ListeningActivityRecord(
      contentId: contentId ?? this.contentId,
      contentType: contentType ?? this.contentType,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      imageUrl: imageUrl ?? this.imageUrl,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      playCount: playCount ?? this.playCount,
      accumulatedListenDurationSec: accumulatedListenDurationSec ?? this.accumulatedListenDurationSec,
      parentAlbumId: parentAlbumId ?? this.parentAlbumId,
      parentPlaylistId: parentPlaylistId ?? this.parentPlaylistId,
      artistId: artistId ?? this.artistId,
      repeatEngagementCount: repeatEngagementCount ?? this.repeatEngagementCount,
      explicitInteractions: explicitInteractions ?? this.explicitInteractions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contentId': contentId,
      'contentType': contentType.name,
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'lastPlayedAt': lastPlayedAt.toIso8601String(),
      'playCount': playCount,
      'accumulatedListenDurationSec': accumulatedListenDurationSec,
      'parentAlbumId': parentAlbumId,
      'parentPlaylistId': parentPlaylistId,
      'artistId': artistId,
      'repeatEngagementCount': repeatEngagementCount,
      'explicitInteractions': explicitInteractions,
    };
  }

  factory ListeningActivityRecord.fromJson(Map<String, dynamic> map) {
    return ListeningActivityRecord(
      contentId: map['contentId'] ?? '',
      contentType: QuickAccessContentType.values.firstWhere(
        (e) => e.name == map['contentType'],
        orElse: () => QuickAccessContentType.song,
      ),
      title: map['title'] ?? '',
      subtitle: map['subtitle'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      lastPlayedAt: DateTime.tryParse(map['lastPlayedAt'] ?? '') ?? DateTime.now(),
      playCount: (map['playCount'] as num?)?.toInt() ?? 1,
      accumulatedListenDurationSec: (map['accumulatedListenDurationSec'] as num?)?.toInt() ?? 0,
      parentAlbumId: map['parentAlbumId'],
      parentPlaylistId: map['parentPlaylistId'],
      artistId: map['artistId'],
      repeatEngagementCount: (map['repeatEngagementCount'] as num?)?.toInt() ?? 0,
      explicitInteractions: (map['explicitInteractions'] as num?)?.toInt() ?? 0,
    );
  }

  String serialize() => jsonEncode(toJson());

  static ListeningActivityRecord? deserialize(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return ListeningActivityRecord.fromJson(map);
      }
    } catch (_) {}
    return null;
  }
}
