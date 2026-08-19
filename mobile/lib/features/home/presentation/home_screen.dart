import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/audio/audio_manager.dart';
import '../../../core/data/mock_catalog.dart';
import '../../../core/services/recommendation_service.dart';
import '../../../shared/components/album_card.dart';
import '../../../shared/components/artist_avatar.dart';
import '../../../shared/components/pill_chip.dart';
import '../../../shared/components/shimmer_box.dart';
import '../../../shared/components/song_tile.dart';
import '../../../shared/components/user_avatar_button.dart';
import '../../../shared/models/song.dart';
import '../../../shared/models/playlist.dart';
import '../../details/presentation/playlist_detail_screen.dart';
import '../../details/presentation/artist_detail_screen.dart';
import '../../details/presentation/see_all_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../player/presentation/player_screen.dart';

enum SongSortOption {
  recentlyAdded('Recently Added', Icons.schedule_rounded),
  titleAZ('Title (A - Z)', Icons.sort_by_alpha_rounded),
  titleZA('Title (Z - A)', Icons.sort_by_alpha_rounded),
  artistAZ('Artist (A - Z)', Icons.person_rounded),
  duration('Duration', Icons.timer_outlined);

  final String label;
  final IconData icon;
  const SongSortOption(this.label, this.icon);
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedFilterIndex = 0;
  final List<String> _filterPills = ['All', 'Music'];
  SongSortOption _currentSort = SongSortOption.recentlyAdded;

  List<Song> _getSortedSongs(List<Song> source) {
    final list = List<Song>.from(source);
    switch (_currentSort) {
      case SongSortOption.recentlyAdded:
        return list;
      case SongSortOption.titleAZ:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        return list;
      case SongSortOption.titleZA:
        list.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        return list;
      case SongSortOption.artistAZ:
        list.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        return list;
      case SongSortOption.duration:
        list.sort((a, b) => b.duration.compareTo(a.duration));
        return list;
    }
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                  child: Row(
                    children: [
                      const Text(
                        'Sort by',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10),
                ...SongSortOption.values.map((option) {
                  final isSelected = _currentSort == option;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
                    leading: Icon(
                      option.icon,
                      color: isSelected ? AppTheme.primaryGreen : Colors.white70,
                      size: 22,
                    ),
                    title: Text(
                      option.label,
                      style: TextStyle(
                        color: isSelected ? AppTheme.primaryGreen : Colors.white,
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded, color: AppTheme.primaryGreen, size: 22)
                        : null,
                    onTap: () {
                      setState(() {
                        _currentSort = option;
                      });
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(musicCatalogProvider);
    final rawSongs = MockMusicCatalog.allSongs;
    final songs = _getSortedSongs(rawSongs);
    final feedAsync = ref.watch(homeFeedProvider);

    final isMusicOnly = _selectedFilterIndex == 1;
    final feed = feedAsync.valueOrNull ?? ref.read(recommendationServiceProvider).generateLocalAlgorithmicFeed();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // FIXED Top Header Bar (Spotify Style)
            Container(
              color: AppTheme.background,
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1 (TOP): Profile Avatar + Filter Pills + Action Icons (Bell, History, Settings)
                  Row(
                    children: [
                      const UserAvatarButton(size: 36),
                      const SizedBox(width: 10),

                      // Filter Pills (All, Music)
                      Expanded(
                        child: SizedBox(
                          height: 30,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _filterPills.length,
                            itemBuilder: (ctx, i) {
                              return PillChip(
                                label: _filterPills[i],
                                isSelected: _selectedFilterIndex == i,
                                onTap: () {
                                  setState(() {
                                    _selectedFilterIndex = i;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),

                      // Action Icons Row (Compact Gap)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                            padding: const EdgeInsets.all(2),
                            constraints: const BoxConstraints(),
                            onPressed: () {},
                          ),
                          const SizedBox(width: 2),
                          IconButton(
                            icon: const Icon(Icons.history_rounded, color: Colors.white, size: 20),
                            padding: const EdgeInsets.all(2),
                            constraints: const BoxConstraints(),
                            onPressed: () {},
                          ),
                          const SizedBox(width: 2),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                            padding: const EdgeInsets.all(2),
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Row 2 (BELOW): Dynamic Greeting or Music Header with Sort Selector
                  if (isMusicOnly)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Music (${songs.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        InkWell(
                          onTap: _showSortBottomSheet,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF242424),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_currentSort.icon, size: 13, color: AppTheme.primaryGreen),
                                const SizedBox(width: 5),
                                Text(
                                  _currentSort.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.white70),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      feed.greeting,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                ],
              ),
            ),

            // Scrollable Content Area
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primaryGreen,
                onRefresh: () async {
                  await MockMusicCatalog.initializeCatalog(forceRefresh: true);
                  await ref.read(homeFeedProvider.notifier).refreshFeed();
                  if (mounted) setState(() {});
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    if (songs.isEmpty) ...[
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppTheme.cardLight,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white10, width: 1.5),
                                  ),
                                  child: const Icon(
                                    Icons.music_note_rounded,
                                    size: 40,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Your Music Library is Fresh',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Upload tracks from your phone to start streaming with Apple Music artwork and Google Drive storage.',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ]
                    // VIEW 1: MUSIC FILTER ACTIVE -> Show full library of sorted songs
                    else if (isMusicOnly) ...[
                      SliverPadding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 140.0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final song = songs[index];
                              return SongTile(
                                song: song,
                                index: index + 1,
                                queueContext: songs,
                                queueIndex: index,
                              );
                            },
                            childCount: songs.length,
                          ),
                        ),
                      ),
                    ]
                    // VIEW 2: ALL TAB ACTIVE -> 100% Dynamic Spotify Algorithmic Feed
                    else ...[
                      // Dynamic Quick-play 6 Cards (Responsive to recent plays & likes)
                      if (feed.quickPlaySongs.isNotEmpty) ...[
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 3.1,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final song = feed.quickPlaySongs[index];
                                return _buildQuickPlayCard(song, index, feed.quickPlaySongs);
                              },
                              childCount: feed.quickPlaySongs.length > 6 ? 6 : feed.quickPlaySongs.length,
                            ),
                          ),
                        ),
                      ],

                      // Dynamically Render Algorithmic Shelves (Spotify & Apple Music Layout)
                      for (final section in feed.sections) ...[
                        if (section.type == HomeSectionType.songs && (section.songs?.isNotEmpty ?? false)) ...[
                          SliverToBoxAdapter(
                            child: _buildSongSection(section),
                          ),
                        ] else if (section.type == HomeSectionType.playlists && (section.playlists?.isNotEmpty ?? false)) ...[
                          SliverToBoxAdapter(
                            child: _buildSectionHeader(
                              section.title,
                              onSeeAll: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => SeeAllScreen(
                                      title: section.title,
                                      type: SeeAllType.playlists,
                                      playlists: section.playlists,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 205,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(left: 16.0),
                                itemCount: section.playlists!.length,
                                itemBuilder: (ctx, i) {
                                  final p = section.playlists![i];
                                  return AlbumCard(
                                    title: p.title,
                                    subtitle: p.description,
                                    imageUrl: p.coverUrl,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (ctx) => PlaylistDetailScreen(playlist: p),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ] else if (section.type == HomeSectionType.albums && (section.albums?.isNotEmpty ?? false)) ...[
                          SliverToBoxAdapter(
                            child: _buildSectionHeader(
                              section.title,
                              onSeeAll: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => SeeAllScreen(
                                      title: section.title,
                                      type: SeeAllType.albums,
                                      albums: section.albums,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 205,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(left: 16.0),
                                itemCount: section.albums!.length > 10 ? 10 : section.albums!.length,
                                itemBuilder: (ctx, i) {
                                  final alb = section.albums![i];
                                  final playlistEquivalent = Playlist(
                                    id: alb.id,
                                    title: alb.title,
                                    description: 'Album • ${alb.artist}',
                                    coverUrl: alb.artworkUrl,
                                    creator: alb.artist,
                                    songs: alb.songs,
                                  );
                                  return AlbumCard(
                                    title: alb.title,
                                    subtitle: 'Album • ${alb.artist}',
                                    imageUrl: alb.artworkUrl,
                                    onTap: () {
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
                        ] else if (section.type == HomeSectionType.artists && (section.artists?.isNotEmpty ?? false)) ...[
                          SliverToBoxAdapter(
                            child: _buildSectionHeader(
                              section.title,
                              onSeeAll: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => SeeAllScreen(
                                      title: section.title,
                                      type: SeeAllType.artists,
                                      artists: section.artists,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 145,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(left: 16.0),
                                itemCount: section.artists!.length > 10 ? 10 : section.artists!.length,
                                itemBuilder: (ctx, i) {
                                  final a = section.artists![i];
                                  return ArtistAvatar(
                                    name: a.name,
                                    imageUrl: a.imageUrl,
                                    radius: 44,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (ctx) => ArtistDetailScreen(artist: a),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ],

                      // Bottom Spacing for floating mini player and navigation bar
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 140),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongSection(HomeSection section) {
    final songList = section.songs ?? [];
    if (songList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          section.title,
          onSeeAll: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => SeeAllScreen(
                  title: section.title,
                  type: SeeAllType.songs,
                  songs: songList,
                ),
              ),
            );
          },
        ),
        SizedBox(
          height: 205,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16.0),
            itemCount: songList.length > 15 ? 15 : songList.length,
            itemBuilder: (ctx, i) {
              final song = songList[i];
              final playerState = ref.watch(playerStateProvider);
              final isCurrent = playerState.currentSong?.id == song.id;

              return AlbumCard(
                title: song.title,
                subtitle: song.artist,
                imageUrl: song.artworkUrl,
                onTap: () {
                  if (isCurrent) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      useSafeArea: false,
                      enableDrag: true,
                      builder: (ctx) => const PlayerScreen(),
                    );
                  } else {
                    ref.read(playerStateProvider.notifier).playSong(
                          song,
                          queue: songList,
                          index: i,
                        );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 22.0, bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  'See all',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickPlayCard(Song song, int index, List<Song> songList) {
    final playerState = ref.watch(playerStateProvider);
    final isCurrent = playerState.currentSong?.id == song.id;

    return Material(
      color: const Color(0xFF282828),
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (isCurrent) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              useSafeArea: false,
              enableDrag: true,
              builder: (ctx) => const PlayerScreen(),
            );
          } else {
            ref.read(playerStateProvider.notifier).playSong(
                  song,
                  queue: songList,
                  index: index,
                );
          }
        },
        child: Row(
          children: [
            MuxizImage(
              imageUrl: song.artworkUrl,
              width: 56,
              height: 56,
              borderRadius: 0,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                song.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
