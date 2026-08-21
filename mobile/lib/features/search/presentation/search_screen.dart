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
import '../../../shared/models/album.dart';
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
  List<Playlist> _matchedPlaylists = [];
  List<Album> _matchedAlbums = [];
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
        _matchedPlaylists = [];
        _matchedAlbums = [];
        _matchedArtists = [];
      });
      return;
    }

    setState(() {
      _query = q;
      _isSearching = true;
    });

    // 150ms Debounce for immediate snappy feedback
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      _performSearch(q);
    });
  }

  Future<void> _performSearch(String q) async {
    if (!mounted) return;

    if (q.trim().length >= 2) {
      _recordSearch(q.trim());
    }

    final queryLower = q.toLowerCase();
    final tokens = queryLower.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    // 1. MATCH SONGS (Every letter / token / substring match in title, artist, album, movie)
    final allSongs = MockMusicCatalog.allSongs;
    final matchedSongs = allSongs.where((s) {
      final title = s.title.toLowerCase();
      final artist = s.artist.toLowerCase();
      final album = s.album.toLowerCase();
      final movie = (s.movieName ?? '').toLowerCase();

      if (title.contains(queryLower) ||
          artist.contains(queryLower) ||
          album.contains(queryLower) ||
          movie.contains(queryLower)) {
        return true;
      }

      if (tokens.isNotEmpty &&
          tokens.every((t) =>
              title.contains(t) ||
              artist.contains(t) ||
              album.contains(t) ||
              movie.contains(t))) {
        return true;
      }
      return false;
    }).toList();

    // Sort songs by prefix match relevance
    matchedSongs.sort((a, b) {
      final aTitle = a.title.toLowerCase();
      final bTitle = b.title.toLowerCase();
      final aStarts = aTitle.startsWith(queryLower);
      final bStarts = bTitle.startsWith(queryLower);
      if (aStarts && !bStarts) return -1;
      if (!aStarts && bStarts) return 1;
      return 0;
    });

    // 2. MATCH PLAYLISTS
    final allPlaylists = <Playlist>[
      ...MockMusicCatalog.featuredPlaylists,
      ...LocalStorageService.getCustomPlaylists(),
    ];
    final seenPlaylistTitles = <String>{};
    final uniquePlaylists = allPlaylists.where((p) => seenPlaylistTitles.add(p.title.toLowerCase())).toList();

    final matchedPlaylists = uniquePlaylists.where((p) {
      final title = p.title.toLowerCase();
      final desc = p.description.toLowerCase();
      if (title.contains(queryLower) || desc.contains(queryLower)) return true;
      return p.songs.any((s) =>
          s.title.toLowerCase().contains(queryLower) ||
          s.artist.toLowerCase().contains(queryLower));
    }).toList();

    // 3. MATCH ALBUMS (Top Albums + Dynamically Grouped Catalog Movie Albums)
    final allAlbums = List<Album>.from(MockMusicCatalog.topAlbums);
    final seenAlbumTitles = allAlbums.map((a) => a.title.toLowerCase()).toSet();

    final movieGroups = <String, List<Song>>{};
    for (final s in allSongs) {
      final key = (s.movieName != null && s.movieName!.isNotEmpty) ? s.movieName! : s.album;
      if (key.isNotEmpty) {
        movieGroups.putIfAbsent(key, () => []).add(s);
      }
    }

    for (final entry in movieGroups.entries) {
      if (!seenAlbumTitles.contains(entry.key.toLowerCase())) {
        allAlbums.add(
          Album(
            id: 'album_${entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
            title: entry.key,
            artist: entry.value.first.artist,
            artworkUrl: entry.value.first.artworkUrl,
            songs: entry.value,
          ),
        );
        seenAlbumTitles.add(entry.key.toLowerCase());
      }
    }

    final matchedAlbums = allAlbums.where((a) {
      final title = a.title.toLowerCase();
      final artist = a.artist.toLowerCase();
      return title.contains(queryLower) || artist.contains(queryLower);
    }).toList();

    // 4. MATCH ARTISTS (Popular Artists + Catalog Artists)
    final allArtists = List<Artist>.from(MockMusicCatalog.popularArtists);
    final seenArtistNames = allArtists.map((a) => a.name.toLowerCase()).toSet();

    for (final s in allSongs) {
      final artistName = MockMusicCatalog.normalizeSingleArtist(s.artist);
      if (artistName.isNotEmpty && !seenArtistNames.contains(artistName.toLowerCase())) {
        allArtists.add(
          Artist(
            id: 'artist_${artistName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
            name: artistName,
            imageUrl: s.artworkUrl,
          ),
        );
        seenArtistNames.add(artistName.toLowerCase());
      }
    }

    final matchedArtists = allArtists.where((a) {
      return a.name.toLowerCase().contains(queryLower);
    }).toList();

    if (mounted) {
      setState(() {
        _matchedSongs = matchedSongs;
        _matchedPlaylists = matchedPlaylists;
        _matchedAlbums = matchedAlbums;
        _matchedArtists = matchedArtists;
        _isSearching = false;
      });
    }

    // Secondary asynchronous backend search sync for remote songs
    try {
      final remoteSongs = await ref.read(apiClientProvider).searchSongs(q);
      if (mounted && remoteSongs.isNotEmpty && _query == q) {
        final existingIds = matchedSongs.map((s) => s.id).toSet();
        final combined = List<Song>.from(matchedSongs);
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
                      // 1. SONGS MATCHES (Rank 1)
                      if (_matchedSongs.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 8.0),
                            child: Text(
                              'Songs (${_matchedSongs.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final song = _matchedSongs[index];
                              return SongTile(
                                song: song,
                                index: index + 1,
                                queueContext: _matchedSongs,
                                queueIndex: index,
                              );
                            },
                            childCount: _matchedSongs.length,
                          ),
                        ),
                      ],

                      // 2. PLAYLISTS MATCHES (Rank 2)
                      if (_matchedPlaylists.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 4.0),
                            child: Text(
                              'Playlists (${_matchedPlaylists.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 184,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              itemCount: _matchedPlaylists.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (ctx, i) {
                                final playlist = _matchedPlaylists[i];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (ctx) => PlaylistDetailScreen(playlist: playlist),
                                      ),
                                    );
                                  },
                                  child: SizedBox(
                                    width: 128,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        MuxizImage(
                                          imageUrl: playlist.coverUrl,
                                          width: 128,
                                          height: 128,
                                          borderRadius: 8,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          playlist.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Playlist • ${playlist.songs.length} songs',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppTheme.textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],

                      // 3. ALBUMS MATCHES (Rank 3)
                      if (_matchedAlbums.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 4.0),
                            child: Text(
                              'Albums (${_matchedAlbums.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 184,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              itemCount: _matchedAlbums.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (ctx, i) {
                                final album = _matchedAlbums[i];
                                return GestureDetector(
                                  onTap: () {
                                    final pl = Playlist(
                                      id: album.id,
                                      title: album.title,
                                      coverUrl: album.artworkUrl,
                                      songs: album.songs,
                                      description: 'Album • ${album.artist} • ${album.releaseYear}',
                                    );
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (ctx) => PlaylistDetailScreen(playlist: pl),
                                      ),
                                    );
                                  },
                                  child: SizedBox(
                                    width: 128,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        MuxizImage(
                                          imageUrl: album.artworkUrl,
                                          width: 128,
                                          height: 128,
                                          borderRadius: 8,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          album.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Album • ${album.artist}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppTheme.textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],

                      // 4. ARTISTS MATCHES (Rank 4)
                      if (_matchedArtists.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 4.0),
                            child: Text(
                              'Artists (${_matchedArtists.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 124,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
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

                      // Empty State if no match in any category
                      if (_matchedSongs.isEmpty &&
                          _matchedPlaylists.isEmpty &&
                          _matchedAlbums.isEmpty &&
                          _matchedArtists.isEmpty)
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
                                    'Try searching for a different song, playlist, album or artist.',
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
                        padding: EdgeInsets.only(left: 16.0, top: 12.0, bottom: 6.0),
                        child: Text(
                          'Browse all',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
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
            description: 'The best of ${category.title}',
            coverUrl: category.imageUrl,
            creator: 'Spotify',
            songs: filteredSongs.isNotEmpty ? filteredSongs : MockMusicCatalog.allSongs,
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
