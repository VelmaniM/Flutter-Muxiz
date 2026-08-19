import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../core/actions/song_action_models.dart';
import '../../core/audio/audio_manager.dart';
import '../../core/storage/download_manager.dart';
import '../../shared/models/song.dart';
import '../../features/player/presentation/player_screen.dart';
import 'shimmer_box.dart';
import 'song_action_modal.dart';

class SongTile extends ConsumerWidget {
  final Song song;
  final int? index;
  final List<Song>? queueContext;
  final VoidCallback? onTap;
  final bool showArtwork;
  final SongActionContext actionContext;
  final SongActionConfig? config;
  final String? playlistId;
  final String? playlistTitle;
  final int? queueIndex;

  const SongTile({
    super.key,
    required this.song,
    this.index,
    this.queueContext,
    this.onTap,
    this.showArtwork = true,
    this.actionContext = SongActionContext.standard,
    this.config,
    this.playlistId,
    this.playlistTitle,
    this.queueIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final downloadMgr = ref.watch(downloadManagerProvider);

    final isCurrentSong = playerState.currentSong?.id == song.id;
    final isPlaying = isCurrentSong && playerState.isPlaying;
    final isDownloaded = downloadMgr.isDownloaded(song.id) || song.isDownloaded;

    final effectiveConfig = config ??
        SongActionConfig(
          context: actionContext,
          playlistId: playlistId,
          playlistTitle: playlistTitle,
          queueIndex: queueIndex ?? index,
        );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ??
            () {
              if (isCurrentSong) {
                // Tapping already playing song opens Full Player Screen
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  useSafeArea: false,
                  enableDrag: true,
                  builder: (ctx) => const PlayerScreen(),
                );
              } else {
                // 1st tap plays song immediately
                final safeIdx = queueContext != null
                    ? queueContext!.indexWhere((s) => s.id == song.id)
                    : 0;
                ref.read(playerStateProvider.notifier).playSong(
                      song,
                      queue: queueContext ?? [song],
                      index: safeIdx >= 0 ? safeIdx : 0,
                    );
              }
            },
        splashColor: Colors.white.withValues(alpha: 0.08),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              // Index or Artwork
              if (index != null && !showArtwork)
                Container(
                  width: 32,
                  alignment: Alignment.centerLeft,
                  child: isCurrentSong
                      ? Icon(
                          isPlaying ? Icons.equalizer_rounded : Icons.play_arrow_rounded,
                          color: AppTheme.primaryGreen,
                          size: 18,
                        )
                      : Text(
                          '$index',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                )
              else if (showArtwork)
                MuxizImage(
                  imageUrl: song.artworkUrl,
                  width: 48,
                  height: 48,
                  borderRadius: 4,
                ),
              if (showArtwork) const SizedBox(width: 12),

              // Title and Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCurrentSong ? AppTheme.primaryGreen : AppTheme.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (isDownloaded) ...[
                          const Icon(Icons.arrow_circle_down_rounded, color: AppTheme.primaryGreen, size: 12),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Three Dots Options
              IconButton(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
                onPressed: () => showSongActionModal(
                  context,
                  ref,
                  song,
                  config: effectiveConfig,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
