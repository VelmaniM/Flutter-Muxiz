import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/data/mock_catalog.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/components/shimmer_box.dart';
import '../../../shared/components/song_tile.dart';
import '../../../shared/components/artist_avatar.dart';
import '../../../shared/components/user_avatar_button.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/song.dart';
import '../../../shared/models/artist.dart';
import '../../../shared/models/playlist.dart';
import '../../details/presentation/artist_detail_screen.dart';
import '../../details/presentation/playlist_detail_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _query = '';
  bool _isSearching = false;
  List<Song> _matchedSongs = [];
  List<Artist> _matchedArtists = [];
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _searchController.addListener(_onSearchChanged);
  }

  void _loadRecentSearches() {
    setState(() {
      _recentSearches = LocalStorageService.getRecentSearches();
    });
  }

  void _recordSearch(String text) {
    final clean = text.trim();
    if (clean.length >= 2) {
      LocalStorageService.addRecentSearch(clean);
      _loadRecentSearches();
    }
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim();
    if (q == _query) return;

    _debounceTimer?.cancel();

    if (q.isEmpty) {
      setState(() {
        _query = '';
        _isSearching = false;
        _matchedSongs = [];
        _matchedArtists = [];
      });
      return;
    }

    setState(() {
      _query = q;
      _isSearching = true;
    });

    // 250ms Debounce to prevent overwhelming network or UI
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _performSearch(q);
    });
  }

  Future<void> _performSearch(String q) async {
    if (!mounted) return;

    if (q.trim().length >= 2) {
      _recordSearch(q.trim());
    }

    // Instant local indexed search first for 0ms responsiveness
    final queryLower = q.toLowerCase();
    final localSongs = MockMusicCatalog.allSongs
        .where((s) =>
            s.title.toLowerCase().contains(queryLower) ||
            s.artist.toLowerCase().contains(queryLower) ||
            s.album.toLowerCase().contains(queryLower) ||
            (s.movieName?.toLowerCase().contains(queryLower) ?? false))
        .toList();

    final localArtists = MockMusicCatalog.popularArtists
        .where((a) => a.name.toLowerCase().contains(queryLower))
        .toList();

    if (mounted) {
      setState(() {
        _matchedSongs = localSongs;
        _matchedArtists = localArtists;
        _isSearching = false;
      });
    }

    // Secondary asynchronous backend search sync
    try {
      final remoteSongs = await ref.read(apiClientProvider).searchSongs(q);
      if (mounted && remoteSongs.isNotEmpty && _query == q) {
        final existingIds = localSongs.map((s) => s.id).toSet();
        final combined = List<Song>.from(localSongs);
        for (final r in remoteSongs) {
          if (!existingIds.contains(r.id)) {
            combined.add(r);
            existingIds.add(r.id);
          }
        }
        setState(() {
          _matchedSongs = combined;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<Song> _getCategorySongs(BrowseCategory category) {
    final all = MockMusicCatalog.allSongs;
    switch (category.id) {
      case 'romance':
        return all.where((s) {
          final t = s.title.toLowerCase();
          final a = s.artist.toLowerCase();
          return t.contains('love') ||
              t.contains('kadhal') ||
              t.contains('kanave') ||
              t.contains('penne') ||
              t.contains('nenj') ||
              t.contains('poo') ||
              t.contains('uyire') ||
              a.contains('sid') ||
              a.contains('pradeep') ||
              a.contains('shreya') ||
              a.contains('chinmayi') ||
              a.contains('haricharan') ||
              a.contains('shweta');
        }).toList();

      case 'hip_hop':
        return all.where((s) {
          final a = s.artist.toLowerCase();
          final t = s.title.toLowerCase();
          return a.contains('hiphop') ||
              a.contains('badshah') ||
              a.contains('paal dabba') ||
              s.genre == 'Hip-Hop' ||
              t.contains('theme') ||
              t.contains('mass') ||
              t.contains('anthem');
        }).toList();

      case 'kuthu':
        return all.where((s) {
          final a = s.artist.toLowerCase();
          final t = s.title.toLowerCase();
          return a.contains('anthony') ||
              a.contains('velmurugan') ||
              a.contains('krishnaraj') ||
              a.contains('senthil') ||
              t.contains('kuthu') ||
              t.contains('aaluma') ||
              t.contains('marana') ||
              t.contains('danga') ||
              t.contains('dabb');
        }).toList();

      case 'pop':
      case 'party':
        return all.where((s) {
          final a = s.artist.toLowerCase();
          final t = s.title.toLowerCase();
          return s.genre == 'Dance' ||
              s.genre == 'Pop' ||
              a.contains('anirudh') ||
              a.contains('paal') ||
              t.contains('party') ||
              t.contains('dance') ||
              t.contains('beat') ||
              t.contains('naa ready') ||
              t.contains('halamithi');
        }).toList();

      case 'melody':
        return all.where((s) {
          final a = s.artist.toLowerCase();
          final t = s.title.toLowerCase();
          return a.contains('rahman') ||
              a.contains('harris') ||
              a.contains('yuvan') ||
              a.contains('karthik') ||
              t.contains('melody') ||
              t.contains('yazhai') ||
              t.contains('vinnai') ||
              t.contains('aaruyire');
        }).toList();

      case 'classics':
        return all.where((s) {
          final a = s.artist.toLowerCase();
          return a.contains('ilaiyaraaja') ||
              a.contains('yesudas') ||
              a.contains('balasubrahmanyam') ||
              a.contains('spb') ||
              a.contains('chitra') ||
              a.contains('hariharan') ||
              a.contains('viswanathan');
        }).toList();

      case 'chill':
        return all.where((s) {
          final t = s.title.toLowerCase();
          final a = s.artist.toLowerCase();
          return t.contains('chill') ||
              t.contains('life') ||
              t.contains('peace') ||
              t.contains('acoustic') ||
              t.contains('instrumental') ||
              a.contains('pradeep') ||
              a.contains('strings') ||
              a.contains('flute');
        }).toList();

      case 'tamil_hits':
      case 'charts':
      default:
        return all.where((s) {
          final m = (s.movieName ?? s.album).toLowerCase();
          return m.contains('leo') ||
              m.contains('master') ||
              m.contains('jailer') ||
              m.contains('mersal') ||
              m.contains('amaran') ||
              m.contains('vikram') ||
              m.contains('goat') ||
              m.contains('petta') ||
              m.contains('soorarai');
        }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(musicCatalogProvider);
    final categories = BrowseCategory.defaultCategories;

    return Scaffold(
      backgroundColor: AppTheme.background,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // FIXED Top Header (Title + Profile / Camera + Search Box)
            Container(
              color: AppTheme.background,
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const UserAvatarButton(size: 36),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Search',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 24),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Search Bar Input
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Colors.black87, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                            cursorColor: Colors.black87,
                            decoration: const InputDecoration(
                              hintText: 'What do you want to listen to?',
                              hintStyle: TextStyle(color: Colors.black54, fontSize: 14),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_query.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.black54, size: 20),
                            onPressed: () {
                              _searchController.clear();
                            },
                          ),
                      ],
                    ),
                  ),
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.only(top: 4.0),
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        color: AppTheme.primaryGreen,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                ],
              ),
            ),

            // Results or Browse All Categories
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primaryGreen,
                onRefresh: () async {
                  await MockMusicCatalog.initializeCatalog(forceRefresh: true);
                  _loadRecentSearches();
                  if (mounted) setState(() {});
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    if (_query.isNotEmpty) ...[
                    // Top Artists Matches
                    if (_matchedArtists.isNotEmpty) ...[
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(left: 16.0, top: 16.0, bottom: 8.0),
                          child: Text(
                            'Artists',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(left: 16.0),
                            itemCount: _matchedArtists.length,
                            itemBuilder: (ctx, i) {
                              final artist = _matchedArtists[i];
                              return ArtistAvatar(
                                name: artist.name,
                                imageUrl: artist.imageUrl,
                                radius: 36,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (ctx) => ArtistDetailScreen(artist: artist),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ],

                    // Songs Matches
                    if (_matchedSongs.isNotEmpty) ...[
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(left: 16.0, top: 16.0, bottom: 8.0),
                          child: Text(
                            'Songs',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final song = _matchedSongs[index];
                            return SongTile(
                              song: song,
                              queueContext: _matchedSongs,
                            );
                          },
                          childCount: _matchedSongs.length,
                        ),
                      ),
                    ],

                    // Empty State if no match
                    if (_matchedArtists.isEmpty && _matchedSongs.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 80.0),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_off_rounded, size: 54, color: AppTheme.textSecondary),
                                const SizedBox(height: 16),
                                Text(
                                  'Couldn\'t find "$_query"',
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Try searching for a different song, artist or album.',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ] else ...[
                    // Recent Searches Section
                    if (_recentSearches.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 14.0, bottom: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Recent searches',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  await LocalStorageService.clearRecentSearches();
                                  _loadRecentSearches();
                                },
                                child: const Text(
                                  'Clear all',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 38,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                            itemCount: _recentSearches.length,
                            itemBuilder: (ctx, i) {
                              final term = _recentSearches[i];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: InputChip(
                                  backgroundColor: const Color(0xFF242424),
                                  label: Text(
                                    term,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                  avatar: const Icon(Icons.history_rounded, size: 16, color: AppTheme.textSecondary),
                                  deleteIcon: const Icon(Icons.close_rounded, size: 14, color: AppTheme.textSecondary),
                                  onDeleted: () async {
                                    await LocalStorageService.removeRecentSearch(term);
                                    _loadRecentSearches();
                                  },
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  onPressed: () {
                                    _searchController.text = term;
                                    _searchController.selection = TextSelection.fromPosition(TextPosition(offset: term.length));
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    ],

                    // Browse All Categories
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(left: 16.0, top: 8.0, bottom: 12.0),
                        child: Text(
                          'Browse all',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.6,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final category = categories[index];
                            return _buildCategoryCard(category);
                          },
                          childCount: categories.length,
                        ),
                      ),
                    ),
                  ],

                  // Bottom Spacing for floating mini player and fixed bottom bar
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 140),
                  ),
                ],
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BrowseCategory category) {
    return Material(
      color: category.color,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final filteredSongs = _getCategorySongs(category);
          final playlist = Playlist(
            id: 'category_${category.id}',
            title: category.title,
            description: 'The best of ${category.title} • ${filteredSongs.length} Songs',
            coverUrl: category.imageUrl,
            creator: 'Spotify',
            songs: filteredSongs.isNotEmpty ? filteredSongs : MockMusicCatalog.allSongs.take(20).toList(),
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => PlaylistDetailScreen(playlist: playlist),
            ),
          );
        },
        child: Stack(
          children: [
            Positioned(
              left: 12,
              top: 12,
              right: 40,
              child: Text(
                category.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Positioned(
              right: -16,
              bottom: -8,
              child: Transform.rotate(
                angle: 25 * (math.pi / 180),
                child: MuxizImage(
                  imageUrl: category.imageUrl,
                  width: 68,
                  height: 68,
                  borderRadius: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
