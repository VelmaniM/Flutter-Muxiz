import 'song.dart';

class ContinueListeningItem {
  final Song song;
  final int progressSeconds;
  final int totalDurationSeconds;
  final DateTime lastListenedAt;
  final String? playlistContextId;

  ContinueListeningItem({
    required this.song,
    required this.progressSeconds,
    required this.totalDurationSeconds,
    required this.lastListenedAt,
    this.playlistContextId,
  });

  double get progressRatio {
    if (totalDurationSeconds <= 0) return 0.0;
    final ratio = progressSeconds / totalDurationSeconds;
    return ratio.clamp(0.0, 1.0);
  }

  String get formattedProgress {
    final curMin = (progressSeconds ~/ 60).toString();
    final curSec = (progressSeconds % 60).toString().padLeft(2, '0');
    final totMin = (totalDurationSeconds ~/ 60).toString();
    final totSec = (totalDurationSeconds % 60).toString().padLeft(2, '0');
    return '$curMin:$curSec / $totMin:$totSec';
  }

  Map<String, dynamic> toJson() => {
    'song': song.toJson(),
    'progressSeconds': progressSeconds,
    'totalDurationSeconds': totalDurationSeconds,
    'lastListenedAt': lastListenedAt.toIso8601String(),
    'playlistContextId': playlistContextId,
  };

  factory ContinueListeningItem.fromJson(Map<String, dynamic> json) {
    return ContinueListeningItem(
      song: Song.fromJson(Map<String, dynamic>.from(json['song'] as Map)),
      progressSeconds: (json['progressSeconds'] as num?)?.toInt() ?? 0,
      totalDurationSeconds: (json['totalDurationSeconds'] as num?)?.toInt() ?? 180,
      lastListenedAt: DateTime.tryParse(json['lastListenedAt']?.toString() ?? '') ?? DateTime.now(),
      playlistContextId: json['playlistContextId']?.toString(),
    );
  }

  ContinueListeningItem copyWith({
    Song? song,
    int? progressSeconds,
    int? totalDurationSeconds,
    DateTime? lastListenedAt,
    String? playlistContextId,
  }) {
    return ContinueListeningItem(
      song: song ?? this.song,
      progressSeconds: progressSeconds ?? this.progressSeconds,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      lastListenedAt: lastListenedAt ?? this.lastListenedAt,
      playlistContextId: playlistContextId ?? this.playlistContextId,
    );
  }
}
