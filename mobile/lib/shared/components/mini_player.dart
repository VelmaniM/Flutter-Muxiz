import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../core/audio/audio_manager.dart';
import '../../core/audio/audio_route.dart';
import '../../core/audio/audio_route_manager.dart';
import '../../features/player/presentation/player_screen.dart';
import 'device_picker_modal.dart';
import 'shimmer_box.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final routeState = ref.watch(audioRouteProvider);
    final currentRoute = routeState.currentRoute;
    final currentSong = playerState.currentSong;

    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    final dominantColor = playerState.dominantColor;

    return Padding(
      padding: const EdgeInsets.only(left: 6.0, right: 6.0, top: 2.0, bottom: 0.0),
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            useSafeArea: false,
            enableDrag: true,
            builder: (ctx) => const PlayerScreen(),
          );
        },
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0.0;
          if (velocity < -200) {
            // Swipe Right to Left -> Next song
            ref.read(playerStateProvider.notifier).skipToNext();
          } else if (velocity > 200) {
            // Swipe Left to Right -> Previous song
            ref.read(playerStateProvider.notifier).skipToPrevious();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(dominantColor, const Color(0xFF242424), 0.25)!,
                Color.lerp(dominantColor, const Color(0xFF101010), 0.70)!,
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: dominantColor.withValues(alpha: 0.35),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: dominantColor.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      // Artwork Thumbnail with Shimmer Loader
                      MuxizImage(
                        imageUrl: currentSong.artworkUrl,
                        width: 42,
                        height: 42,
                        borderRadius: 6,
                      ),
                      const SizedBox(width: 10),

                      // Title and Artist
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentSong.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentSong.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Device / Connect Icon (Auto-detects Bluetooth / AirPods / Speaker)
                      IconButton(
                        icon: Icon(
                          currentRoute != null
                              ? currentRoute.icon
                              : Icons.speaker_group_outlined,
                          color: (currentRoute != null && currentRoute.type != AudioRouteType.speaker)
                              ? AppTheme.primaryGreen
                              : AppTheme.textSecondary,
                          size: 20,
                        ),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (ctx) => const DevicePickerModal(),
                          );
                        },
                      ),

                      // Play/Pause Button
                      IconButton(
                        icon: Icon(
                          playerState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () {
                          ref.read(playerStateProvider.notifier).togglePlayPause();
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Linear Progress Bar
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                child: LinearProgressIndicator(
                  value: playerState.progressRatio,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 2.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
