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
import '../../main_layout.dart';

import '../../../core/storage/local_storage.dart';
import '../../../core/services/listening_tracker_service.dart';
import '../../../shared/models/listening_activity.dart';

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
  late SongSortOption _currentSort;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final saved = LocalStorageService.getMusicSortOption();
    _currentSort = SongSortOption.values.firstWhere(
      (o) => o.name == saved,
      orElse: () => SongSortOption.recentlyAdded,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
      backgroundColor: const Color(0xFF16161C),
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
                      LocalStorageService.saveMusicSortOption(option.name);
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
    final isMusicOnly = _selectedFilterIndex == 1;
    final songs = isMusicOnly ? _getSortedSongs(MockMusicCatalog.allSongs) : const <Song>[];
    final feedAsync = ref.watch(homeFeedProvider);
    final currentPlayingSongId = ref.watch(playerStateProvider.select((s) => s.currentSong?.id));
    final isAudioPlaying = ref.watch(playerStateProvider.select((s) => s.isPlaying));

    final feed = feedAsync.valueOrNull ?? ref.read(homeFeedProvider.notifier).cachedFeed;

    // Listen for bottom bar Home icon re-tap to reset filter to All and scroll to top
    ref.listen(homeResetTriggerProvider, (prev, next) {
      if (next != prev) {
        setState(() {
          _selectedFilterIndex = 0; // Switch to "All"
        });
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // FIXED Top Header Bar: Clean, Minimal, Comfortable
            Container(
              color: AppTheme.background,
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1 (TOP): Profile Avatar + Filter Pills + Action Icons
                  Row(
                    children: [
                      const UserAvatarButton(size: 36),
                      const SizedBox(width: 12),

                      // Filter Pills (All, Music)
                      Expanded(
                        child: SizedBox(
                          height: 32,
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
                      const SizedBox(width: 4),

                      // Action Icons Row with comfortable tap targets
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 21),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.history_rounded, color: Colors.white, size: 21),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 21),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
                  // Row 2: Sort Selector (Only when Music Filter is active)
                  if (isMusicOnly) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Music',
                          style: TextStyle(
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A22),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_currentSort.icon, size: 14, color: AppTheme.primaryGreen),
                                const SizedBox(width: 6),
                                Text(
                                  _currentSort.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.white70),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Content Area: Live Feed & Full Design UI (Zero Continue Listening Section)
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // VIEW 1: MUSIC FILTER ACTIVE -> Show full library of sorted songs
                  if (isMusicOnly) ...[
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
                  // VIEW 2: ALL TAB ACTIVE -> 100% Dynamic Spotify & Apple Music Inspired Feed
                  else ...[
                    // Empty state on brand new install with 0 songs
                    if (MockMusicCatalog.allSongs.isEmpty) ...[
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.primaryGreen.withValues(alpha: 0.25),
                                        const Color(0xFF1DB954).withValues(alpha: 0.08),
                                      ],
                                    ),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.music_note_rounded, color: AppTheme.primaryGreen, size: 32),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'No songs in library yet',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Upload tracks from Muxiz Studio to start listening',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                                ),
                                const SizedBox(height: 18),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A1A22),
                                    foregroundColor: AppTheme.primaryGreen,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    side: const BorderSide(color: Colors.white12),
                                  ),
                                  onPressed: () => MockMusicCatalog.initializeCatalog(forceRefresh: true),
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  label: const Text('Sync with Studio'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Dynamic Greeting Section with Side Accent Bar (Below top bar)
                      SliverPadding(
                        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 14.0, bottom: 4.0),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            children: [
                              Container(
                                width: 3.5,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Builder(
                                builder: (context) {
                                  final rawName = LocalStorageService.getUserName();
                                  final displayName = rawName.isNotEmpty ? rawName.trim().split(' ').first : '';
                                  final fullGreeting = displayName.isNotEmpty ? '${feed.greeting}, $displayName' : feed.greeting;
                                  return Text(
                                    fullGreeting,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Dynamic Quick-play 6 Cards (Refined, Aesthetic 2-Column Grid)
                      if (feed.quickPlayCards.isNotEmpty) ...[
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisExtent: 48,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final card = feed.quickPlayCards[index];
                                return _buildQuickPlayCard(card, index, currentPlayingSongId, isAudioPlaying);
                              },
                              childCount: feed.quickPlayCards.length > 6 ? 6 : feed.quickPlayCards.length,
                            ),
                          ),
                        ),
                      ],

                      // Dynamically Render Algorithmic Shelves (Zero Continue Listening Section)
                      for (final section in feed.sections) ...[
                        if (section.type == HomeSectionType.songs && (section.songs?.isNotEmpty ?? false)) ...[
                          SliverToBoxAdapter(
                            child: _buildSongSection(section, currentPlayingSongId),
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
                              height: 180,
                              child: ListView.builder(
                                physics: const BouncingScrollPhysics(),
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
                                      ListeningTrackerService.instance.recordFastLocalOpen(
                                        'playlist_${p.id}',
                                        p.title,
                                        QuickAccessContentType.playlist,
                                        p.coverUrl,
                                        subtitle: p.description,
                                      );
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
                              height: 180,
                              child: ListView.builder(
                                physics: const BouncingScrollPhysics(),
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
                                      ListeningTrackerService.instance.recordFastLocalOpen(
                                        alb.id,
                                        alb.title,
                                        QuickAccessContentType.album,
                                        alb.artworkUrl,
                                        subtitle: 'Album • ${alb.artist}',
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
                              height: 155,
                              child: ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(left: 16.0),
                                itemCount: section.artists!.length > 10 ? 10 : section.artists!.length,
                                itemBuilder: (ctx, i) {
                                  final a = section.artists![i];
                                  return ArtistAvatar(
                                    name: a.name,
                                    imageUrl: a.imageUrl,
                                    radius: 46,
                                    onTap: () {
                                      ListeningTrackerService.instance.recordFastLocalOpen(
                                        'artist_${a.id}',
                                        a.name,
                                        QuickAccessContentType.artist,
                                        a.imageUrl,
                                        subtitle: 'Artist',
                                      );
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongSection(HomeSection section, String? currentPlayingSongId) {
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
          height: 180,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16.0),
            itemCount: songList.length,
            itemBuilder: (ctx, i) {
              final song = songList[i];
              final isCurrent = currentPlayingSongId == song.id;

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
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
                child: Text(
                  'See all',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickPlayCard(QuickPlayCardItem item, int index, String? currentPlayingSongId, bool isAudioPlaying) {
    final isCurrent = item.song != null && currentPlayingSongId == item.song!.id;

    return RepaintBoundary(
      key: ValueKey('q_card_${item.id}_$index'),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16161C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
            width: 0.8,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          if (item.song != null) {
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
              ref.read(playerStateProvider.notifier).playSong(item.song!);
            }
          } else if (item.album != null) {
            ListeningTrackerService.instance.recordFastLocalOpen(
              item.album!.id,
              item.album!.title,
              QuickAccessContentType.album,
              item.album!.artworkUrl,
              subtitle: 'Album • ${item.album!.artist}',
            );
            final playlistEquivalent = Playlist(
              id: item.album!.id,
              title: item.album!.title,
              description: 'Album • ${item.album!.artist}',
              coverUrl: item.album!.artworkUrl,
              creator: item.album!.artist,
              songs: item.album!.songs,
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => PlaylistDetailScreen(playlist: playlistEquivalent),
              ),
            );
          } else if (item.playlist != null) {
            ListeningTrackerService.instance.recordFastLocalOpen(
              'playlist_${item.playlist!.id}',
              item.playlist!.title,
              QuickAccessContentType.playlist,
              item.playlist!.coverUrl,
              subtitle: 'Playlist',
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => PlaylistDetailScreen(playlist: item.playlist!),
              ),
            );
          } else if (item.artist != null) {
            ListeningTrackerService.instance.recordFastLocalOpen(
              'artist_${item.artist!.id}',
              item.artist!.name,
              QuickAccessContentType.artist,
              item.artist!.imageUrl,
              subtitle: 'Artist',
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => ArtistDetailScreen(artist: item.artist!),
              ),
            );
          }
        },
        child: Row(
          children: [
            MuxizImage(
              imageUrl: item.imageUrl,
              width: 48,
              height: 48,
              borderRadius: 6,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isCurrent ? AppTheme.primaryGreen : Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            if (isCurrent)
              Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: Icon(
                  isAudioPlaying ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                  size: 16,
                  color: AppTheme.primaryGreen,
                ),
              )
            else
              const SizedBox(width: 6),
          ],
        ),
      ),
    ),
    );
  }
}
