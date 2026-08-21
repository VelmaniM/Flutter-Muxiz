import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../core/audio/audio_manager.dart';
import '../../core/audio/audio_route_manager.dart';
import '../../features/player/presentation/player_screen.dart';
import 'device_picker_modal.dart';
import 'shimmer_box.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(playerStateProvider.select((s) => s.currentSong));
    final isPlaying = ref.watch(playerStateProvider.select((s) => s.isPlaying));
    final dominantColor = ref.watch(playerStateProvider.select((s) => s.dominantColor));
    final routeState = ref.watch(audioRouteProvider);
    final currentRoute = routeState.currentRoute;

    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    final Color primaryTone = dominantColor;
    final Color bgStart = Color.lerp(primaryTone, const Color(0xFF181820), 0.40) ?? const Color(0xFF222228);
    final Color bgEnd = Color.lerp(primaryTone, const Color(0xFF0F0F14), 0.75) ?? const Color(0xFF14141A);
    final Color borderColor = primaryTone.withValues(alpha: 0.35);

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
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [bgStart, bgEnd],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor,
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryTone.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 16,
                offset: const Offset(0, 4),
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
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                letterSpacing: -0.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black87,
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentSong.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                                letterSpacing: -0.1,
                                shadows: [
                                  Shadow(
                                    color: Colors.black87,
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Audio Output Route Picker Icon (Live Dynamic Hardware Detection)
                      IconButton(
                        icon: Icon(
                          currentRoute?.icon ?? Icons.phone_iphone_rounded,
                          color: AppTheme.primaryGreen,
                          size: 20,
                        ),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => const DevicePickerModal(),
                          );
                        },
                      ),

                      // Play/Pause Button
                      IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
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

              // Bottom Linear Progress Bar (Isolated high-performance listener)
              _MiniPlayerProgressBar(accentColor: dominantColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniPlayerProgressBar extends ConsumerWidget {
  final Color? accentColor;
  const _MiniPlayerProgressBar({this.accentColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressRatio = ref.watch(playerStateProvider.select((s) => s.progressRatio));

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(8),
        bottomRight: Radius.circular(8),
      ),
      child: LinearProgressIndicator(
        value: progressRatio,
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        minHeight: 2.2,
      ),
    );
  }
}
