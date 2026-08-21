import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/actions/song_action_models.dart';
import '../../../core/audio/audio_manager.dart';
import '../../../core/data/mock_catalog.dart';
import '../../../shared/components/glass_bottom_bar.dart';
import '../../../shared/components/mini_player.dart';
import '../../../shared/components/shimmer_box.dart';
import '../../../shared/components/album_card.dart';
import '../../../shared/components/song_tile.dart';
import '../../../shared/models/artist.dart';
import '../../../shared/models/playlist.dart';
import '../../main_layout.dart';
import 'playlist_detail_screen.dart';

class ArtistDetailScreen extends ConsumerStatefulWidget {
  final Artist artist;

  const ArtistDetailScreen({
    super.key,
    required this.artist,
  });

  @override
  ConsumerState<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends ConsumerState<ArtistDetailScreen> {
  bool _isFollowing = false;

  @override
  Widget build(BuildContext context) {
    final artist = widget.artist;
    // Strict artist song filtering - ONLY songs strictly by this artist
    final effectiveTracks = MockMusicCatalog.getSongsForArtist(artist.name);

    // Filter albums strictly belonging to this artist
    final artistAlbums = MockMusicCatalog.topAlbums.where((alb) {
      return MockMusicCatalog.normalizeArtistName(alb.artist).toLowerCase() ==
              MockMusicCatalog.normalizeArtistName(artist.name).toLowerCase() ||
          alb.songs.any((s) => MockMusicCatalog.isSongByArtist(s, artist.name));
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Parallax Hero Banner with Seamless Fade
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                artist.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  MuxizImage(
                    imageUrl: artist.imageUrl,
                    borderRadius: 0,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(0x40000000),
                          Color(0xAA000000),
                          Color(0xFF000000),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.35, 0.70, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Color(0x90000000),
                            Color(0xFF000000),
                          ],
                          stops: [0.0, 0.40, 1.0],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 48,
                    left: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (artist.isVerified)
                          const Row(
                            children: [
                              Icon(Icons.verified_rounded, color: Color(0xFF3D91F4), size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Verified Artist',
                                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '${artist.monthlyListeners} monthly listeners',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Actions Row: Follow, More, Big Green Play
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _isFollowing ? AppTheme.primaryGreen : Colors.white60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    ),
                    onPressed: () {
                      setState(() {
                        _isFollowing = !_isFollowing;
                      });
                    },
                    child: Text(
                      _isFollowing ? 'FOLLOWING' : 'FOLLOW',
                      style: TextStyle(
                        color: _isFollowing ? AppTheme.primaryGreen : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary, size: 24),
                    onPressed: () {},
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      if (effectiveTracks.isNotEmpty) {
                        ref.read(playerStateProvider.notifier).playSong(
                              effectiveTracks[0],
                              queue: effectiveTracks,
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
            ),
          ),

          // Popular Header
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 4.0),
              child: Text(
                'Popular',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Top Tracks List (or Empty Message)
          if (effectiveTracks.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: Center(
                  child: Text(
                    'No songs found for ${artist.name}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final s = effectiveTracks[index];
                  return SongTile(
                    song: s,
                    index: index + 1,
                    queueContext: effectiveTracks,
                    showArtwork: true,
                    actionContext: SongActionContext.artist,
                  );
                },
                childCount: effectiveTracks.length,
              ),
            ),

          // Popular Releases Section (Only if albums exist for this artist)
          if (artistAlbums.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(left: 16.0, top: 16.0, bottom: 4.0),
                child: Text(
                  'Popular Releases',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 195,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16.0),
                  itemCount: artistAlbums.length,
                  itemBuilder: (ctx, i) {
                    final alb = artistAlbums[i];
                    return AlbumCard(
                      title: alb.title,
                      subtitle: 'Album • ${alb.releaseYear}',
                      imageUrl: alb.artworkUrl,
                      onTap: () {
                        final playlistEquivalent = Playlist(
                          id: alb.id,
                          title: alb.title,
                          description: 'Album • ${alb.artist} • ${alb.releaseYear}',
                          coverUrl: alb.artworkUrl,
                          creator: alb.artist,
                          songs: alb.songs,
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => PlaylistDetailScreen(playlist: playlistEquivalent),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],

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
              ref.read(selectedTabProvider.notifier).setTab(index);
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }
}
