import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/actions/song_action_models.dart';
import '../../../core/audio/audio_manager.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/components/glass_bottom_bar.dart';
import '../../../shared/components/mini_player.dart';
import '../../../shared/components/shimmer_box.dart';
import '../../../shared/components/song_tile.dart';
import '../../../shared/models/playlist.dart';
import '../../../shared/models/song.dart';
import '../../main_layout.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Song> songs = playlist.songs;

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Collapsible Ambient Header with Smooth Bottom Gradient Fade
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  // 1. Ambient Background Layer
                  Container(
                    color: Colors.black,
                  ),
                  if (playlist.coverUrl.isNotEmpty) ...[
                    Opacity(
                      opacity: 0.20,
                      child: MuxizImage(
                        imageUrl: playlist.coverUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        borderRadius: 0,
                      ),
                    ),
                  ],
                  // 2. Full-bleed Multi-Stop Black Gradient Mask (Ultra Smooth)
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x30000000),
                          Color(0x70000000),
                          Color(0xC0000000),
                          Color(0xFF000000),
                        ],
                        stops: [0.0, 0.40, 0.75, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // 3. Centered Artwork with Soft Glow Shadow
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 36),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.7),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: MuxizImage(
                          imageUrl: playlist.coverUrl,
                          width: 152,
                          height: 152,
                          borderRadius: 8,
                        ),
                      ),
                    ],
                  ),
                  // 4. Bottom Edge Dissolve Overlay (Completely eliminates any hard boundary)
                  Positioned(
                    bottom: -1,
                    left: 0,
                    right: 0,
                    height: 70,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Color(0x80000000),
                            Color(0xFF000000),
                          ],
                          stops: [0.0, 0.45, 1.0],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Metadata & Controls
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    playlist.description,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_pin, color: AppTheme.primaryGreen, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Created by ${playlist.creator}',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '•  ${songs.length} tracks',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Actions Row: Download, More, Big Play Button
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_circle_down_outlined, color: AppTheme.textSecondary, size: 26),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary, size: 24),
                        onPressed: () => _showPlaylistMenu(context, ref, playlist),
                      ),
                      const Spacer(),
                      // Big Green Play/Shuffle Button
                      GestureDetector(
                        onTap: () {
                          if (songs.isNotEmpty) {
                            ref.read(playerStateProvider.notifier).playSong(
                                  songs[0],
                                  queue: songs,
                                  index: 0,
                                );
                          }
                        },
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryGreen,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryGreen,
                                blurRadius: 10,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 34),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Songs List
          if (songs.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.music_off_rounded, color: AppTheme.textSecondary, size: 48),
                      SizedBox(height: 12),
                      Text(
                        'No songs here yet',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Find and add songs to this playlist',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final s = songs[index];
                  return SongTile(
                    song: s,
                    queueContext: songs,
                    showArtwork: true,
                    actionContext: SongActionContext.playlist,
                    playlistId: playlist.id,
                    playlistTitle: playlist.title,
                  );
                },
                childCount: songs.length,
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          GlassBottomBar(
            currentIndex: ref.watch(selectedTabProvider),
            onTabSelected: (index) {
              ref.read(selectedTabProvider.notifier).state = index;
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }

  void _showPlaylistMenu(BuildContext context, WidgetRef ref, Playlist playlist) {
    final isLiked = playlist.id == 'liked_songs';
    final isCustom = ref.read(customPlaylistsProvider).any((cp) => cp.id == playlist.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    MuxizImage(
                      imageUrl: playlist.coverUrl,
                      width: 52,
                      height: 52,
                      borderRadius: 6,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Playlist • ${playlist.songs.length} songs',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 6),

                if (isCustom || !isLiked)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
                    title: const Text(
                      'Delete playlist',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Delete from library and database',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmDeletePlaylist(context, ref, playlist);
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeletePlaylist(BuildContext context, WidgetRef ref, Playlist playlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222222),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Delete Playlist?',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to delete "${playlist.title}"? This cannot be undone.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await ref.read(customPlaylistsProvider.notifier).deletePlaylist(playlist.id);
                          if (context.mounted) {
                            Navigator.pop(context); // Exit detail screen
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
