import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/actions/song_action_models.dart';
import '../../../core/audio/audio_manager.dart';
import '../../../core/audio/audio_route.dart';
import '../../../core/audio/audio_route_manager.dart';
import '../../../shared/models/song.dart';
import '../../../shared/components/device_picker_modal.dart';
import '../../../shared/components/shimmer_box.dart';
import '../../../shared/components/song_action_modal.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _isSeeking = false;
  double _seekValue = 0.0;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerStateProvider);
    final song = playerState.currentSong;

    if (song == null) {
      return const SizedBox.shrink();
    }

    final dominantColor = playerState.dominantColor;
    final routeState = ref.watch(audioRouteProvider);
    final currentRoute = routeState.currentRoute;

    final totalDurationMs = playerState.duration.inMilliseconds > 0
        ? playerState.duration.inMilliseconds
        : (song.duration * 1000);
    final rawPosMs = playerState.position.inMilliseconds;
    final currentPositionMs = _isSeeking
        ? (_seekValue * (totalDurationMs > 0 ? totalDurationMs : 1)).round()
        : (totalDurationMs > 0 ? rawPosMs.clamp(0, totalDurationMs) : 0);

    final currentSec = (currentPositionMs / 1000).floor().clamp(0, 99999);
    final totalSec = (totalDurationMs / 1000).floor().clamp(0, 99999);

    final currentPosFormatted = '${currentSec ~/ 60}:${(currentSec % 60).toString().padLeft(2, '0')}';
    final totalDurFormatted = '${totalSec ~/ 60}:${(totalSec % 60).toString().padLeft(2, '0')}';

    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top > 0
        ? mediaQuery.padding.top
        : (mediaQuery.viewPadding.top > 0 ? mediaQuery.viewPadding.top : 48.0);
    final bottomPadding = math.max(mediaQuery.padding.bottom, 16.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      width: double.infinity,
      height: mediaQuery.size.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            dominantColor.withValues(alpha: 0.95),
            Color.lerp(dominantColor, const Color(0xFF181818), 0.50)!,
            Color.lerp(dominantColor, const Color(0xFF0F0F0F), 0.82)!,
            const Color(0xFF080808),
          ],
          stops: const [0.0, 0.35, 0.70, 1.0],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: EdgeInsets.only(
            left: 22.0,
            right: 22.0,
            top: topPadding + 6.0,
            bottom: math.max(bottomPadding, 16.0),
          ),
          child: Column(
            children: [
              // 1. Top Navigation Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'PLAYING FROM PLAYLIST',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.album,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
                    onPressed: () => showSongActionModal(
                      context,
                      ref,
                      song,
                      config: const SongActionConfig(context: SongActionContext.fullPlayer),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 2. Large Album Artwork
              Expanded(
                flex: 6,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.55),
                            blurRadius: 26,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: MuxizImage(
                          imageUrl: song.artworkUrl,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 3. Track Title & Artist Info + Add to Playlist
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Add to Playlist +
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                    onPressed: () => showSongActionModal(
                      context,
                      ref,
                      song,
                      config: const SongActionConfig(context: SongActionContext.fullPlayer),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 4. Seek Bar Slider & Timestamps
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.5,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                  thumbColor: Colors.white,
                  overlayColor: Colors.white.withValues(alpha: 0.1),
                ),
                child: Slider(
                  value: _isSeeking
                      ? _seekValue
                      : (totalDurationMs > 0 ? (currentPositionMs / totalDurationMs).clamp(0.0, 1.0) : 0.0),
                  onChanged: (val) {
                    setState(() {
                      _isSeeking = true;
                      _seekValue = val;
                    });
                  },
                  onChangeEnd: (val) {
                    final targetMs = (val * (totalDurationMs > 0 ? totalDurationMs : 1)).round();
                    ref.read(playerStateProvider.notifier).seek(Duration(milliseconds: targetMs));
                    setState(() {
                      _isSeeking = false;
                    });
                  },
                ),
              ),

              // Timestamps (Position & Duration)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      currentPosFormatted,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      totalDurFormatted,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 5. Playback Control Buttons (Shuffle, Prev, Play/Pause, Next, Repeat)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Shuffle
                  IconButton(
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: playerState.isShuffling ? AppTheme.primaryGreen : Colors.white.withValues(alpha: 0.65),
                      size: 24,
                    ),
                    onPressed: () {
                      ref.read(playerStateProvider.notifier).toggleShuffle();
                    },
                  ),

                  // Previous
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 36),
                    onPressed: () {
                      ref.read(playerStateProvider.notifier).skipToPrevious();
                    },
                  ),

                  // Play / Pause Circle
                  GestureDetector(
                    onTap: () {
                      ref.read(playerStateProvider.notifier).togglePlayPause();
                    },
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: Icon(
                        playerState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 38,
                      ),
                    ),
                  ),

                  // Next
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 36),
                    onPressed: () {
                      ref.read(playerStateProvider.notifier).skipToNext();
                    },
                  ),

                  // Repeat
                  IconButton(
                    icon: Icon(
                      playerState.repeatMode == AudioRepeatMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: playerState.repeatMode != AudioRepeatMode.off
                          ? AppTheme.primaryGreen
                          : Colors.white.withValues(alpha: 0.65),
                      size: 24,
                    ),
                    onPressed: () {
                      ref.read(playerStateProvider.notifier).toggleRepeat();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 6. Bottom Action Bar (Live Connected Device, Queue)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (ctx) => const DevicePickerModal(),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          currentRoute != null
                              ? currentRoute.icon
                              : Icons.speaker_group_outlined,
                          color: (currentRoute != null && currentRoute.type != AudioRouteType.speaker)
                              ? AppTheme.primaryGreen
                              : AppTheme.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currentRoute != null ? currentRoute.name : 'Audio Output',
                          style: TextStyle(
                            color: (currentRoute != null && currentRoute.type != AudioRouteType.speaker)
                                ? AppTheme.primaryGreen
                                : AppTheme.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.queue_music_rounded, color: AppTheme.textSecondary, size: 24),
                    onPressed: () => _showQueueModal(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Queue Modal with Centralized Contextual Song Actions & Reordering ---
  void _showQueueModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, child) {
            final playerState = ref.watch(playerStateProvider);
            final queue = playerState.queue;
            final currentIndex = playerState.queueIndex;

            // Up Next queue: Only future upcoming songs (Played songs are cleanly excluded)
            final upNext = (currentIndex + 1 < queue.length)
                ? queue.sublist(currentIndex + 1)
                : <Song>[];

            return SafeArea(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Playback Queue',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${upNext.length + (playerState.currentSong != null ? 1 : 0)} tracks',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 1. Now Playing Section
                    if (playerState.currentSong != null) ...[
                      const Text(
                        'Now Playing',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: MuxizImage(
                          imageUrl: playerState.currentSong!.artworkUrl,
                          width: 44,
                          height: 44,
                          borderRadius: 4,
                        ),
                        title: Text(
                          playerState.currentSong!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          playerState.currentSong!.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 20),
                          onPressed: () {
                            showSongActionModal(
                              context,
                              ref,
                              playerState.currentSong!,
                              config: const SongActionConfig(
                                context: SongActionContext.fullPlayer,
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(color: AppTheme.divider, height: 20),
                    ],

                    // 2. Next in Queue (Up Next) Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Next in Queue',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        if (upNext.isNotEmpty)
                          Text(
                            '${upNext.length} upcoming',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (upNext.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text(
                              'No upcoming tracks in queue.\nTap "+ Add to Queue" or "▶ Play Next" on any song to add it here!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ReorderableListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: upNext.length,
                          // ignore: deprecated_member_use
                          onReorder: (oldIdx, newIdx) {
                            final realOld = currentIndex + 1 + oldIdx;
                            final realNew = currentIndex + 1 + newIdx;
                            ref.read(playerStateProvider.notifier).reorderQueue(realOld, realNew);
                          },
                          itemBuilder: (ctx, i) {
                            final item = upNext[i];
                            final realQueueIndex = currentIndex + 1 + i;

                            return ListTile(
                              key: ValueKey('up_next_item_${item.id}_$i'),
                              contentPadding: EdgeInsets.zero,
                              leading: MuxizImage(
                                imageUrl: item.artworkUrl,
                                width: 40,
                                height: 40,
                                borderRadius: 4,
                              ),
                              title: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                item.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary, size: 20),
                                    onPressed: () {
                                      showSongActionModal(
                                        context,
                                        ref,
                                        item,
                                        config: SongActionConfig(
                                          context: SongActionContext.queue,
                                          queueIndex: realQueueIndex,
                                          isQueueItem: true,
                                        ),
                                      );
                                    },
                                  ),
                                  ReorderableDragStartListener(
                                    index: i,
                                    child: const Icon(Icons.drag_handle_rounded, color: Colors.white38, size: 20),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                ref.read(playerStateProvider.notifier).playSong(
                                      item,
                                      queue: queue,
                                      index: realQueueIndex,
                                    );
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
