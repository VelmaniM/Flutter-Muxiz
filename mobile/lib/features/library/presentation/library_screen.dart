import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/actions/song_action_models.dart';
import '../../../core/data/mock_catalog.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/components/pill_chip.dart';
import '../../../shared/components/shimmer_box.dart';
import '../../../shared/components/song_tile.dart';
import '../../../shared/components/user_avatar_button.dart';
import '../../../shared/models/playlist.dart';
import '../../../shared/models/album.dart';
import '../../../shared/models/artist.dart';
import '../../details/presentation/playlist_detail_screen.dart';
import '../../details/presentation/artist_detail_screen.dart';
import '../../../core/services/recommendation_service.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _selectedFilter = 0;
  final List<String> _filters = ['Playlists', 'Downloaded', 'Artists', 'Albums'];
  bool _isGridView = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Load persistent user preference for Grid vs List view (defaults to List)
    _isGridView = LocalStorageService.getLibraryIsGridView();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleViewMode() {
    setState(() {
      _isGridView = !_isGridView;
    });
    // Persist user preference
    LocalStorageService.setLibraryIsGridView(_isGridView);
  }

  @override
  Widget build(BuildContext context) {
    final downloadedSongs = LocalStorageService.getDownloadedSongs();
    final customPlaylists = ref.watch(customPlaylistsProvider);
    final allArtists = MockMusicCatalog.popularArtists;
    final allAlbums = MockMusicCatalog.topAlbums;
    final allPlaylists = customPlaylists;

    // Filter by search query
    final playlists = _searchQuery.isEmpty
        ? allPlaylists
        : allPlaylists.where((p) => p.title.toLowerCase().contains(_searchQuery) || p.description.toLowerCase().contains(_searchQuery)).toList();

    final filteredDownloads = _searchQuery.isEmpty
        ? downloadedSongs
        : downloadedSongs.where((s) => s.title.toLowerCase().contains(_searchQuery) || s.artist.toLowerCase().contains(_searchQuery)).toList();

    final artists = _searchQuery.isEmpty
        ? allArtists
        : allArtists.where((a) => a.name.toLowerCase().contains(_searchQuery)).toList();

    final albums = _searchQuery.isEmpty
        ? allAlbums
        : allAlbums.where((alb) => alb.title.toLowerCase().contains(_searchQuery) || alb.artist.toLowerCase().contains(_searchQuery)).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // FIXED Top Header Bar
            Container(
              color: AppTheme.background,
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 4.0),
              child: Column(
                children: [
                  // Row 1: Header or Search Input Bar
                  if (!_isSearching)
                    Row(
                      children: [
                        const UserAvatarButton(size: 36),
                        const SizedBox(width: 10),
                        const Text(
                          'Your Library',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
                          onPressed: () {
                            setState(() {
                              _isSearching = true;
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                          onPressed: () => _showCreatePlaylistDialog(context),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF282828),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              cursorColor: AppTheme.primaryGreen,
                              decoration: InputDecoration(
                                hintText: 'Search in ${_filters[_selectedFilter]}...',
                                hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                        onPressed: () => _searchController.clear(),
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isSearching = false;
                              _searchController.clear();
                            });
                          },
                          child: const Text('Cancel', style: TextStyle(color: Colors.white, fontSize: 14)),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),

                  // Filter Pills
                  SizedBox(
                    height: 34,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      itemBuilder: (ctx, i) {
                        return PillChip(
                          label: _filters[i],
                          isSelected: _selectedFilter == i,
                          onTap: () {
                            setState(() {
                              _selectedFilter = i;
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Sort & Persistent Grid / List Toggle Row (Icon only)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.swap_vert_rounded, color: AppTheme.textSecondary, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            _selectedFilter == 0
                                ? 'Playlists (${playlists.length})'
                                : (_selectedFilter == 1
                                    ? 'Downloaded (${filteredDownloads.length})'
                                    : (_selectedFilter == 2
                                        ? 'Artists (${artists.length})'
                                        : 'Albums (${albums.length})')),
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                          color: AppTheme.primaryGreen,
                          size: 22,
                        ),
                        onPressed: _toggleViewMode,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Content Area (Dynamic 3-Column Grid vs List)
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
                  // 1. Downloaded Filter
                  if (_selectedFilter == 1) ...[
                    if (filteredDownloads.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_circle_down_rounded, size: 54, color: AppTheme.textSecondary),
                              SizedBox(height: 12),
                              Text(
                                'No downloaded songs yet',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Download songs to listen offline anytime.',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 120.0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final song = filteredDownloads[index];
                              return SongTile(
                                song: song,
                                queueContext: filteredDownloads,
                                actionContext: SongActionContext.downloads,
                              );
                            },
                            childCount: filteredDownloads.length,
                          ),
                        ),
                      ),
                  ]

                  // 2. Artists Filter
                  else if (_selectedFilter == 2) ...[
                    if (artists.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'No matching artists found',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                          ),
                        ),
                      )
                    else if (_isGridView)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.78,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 12,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final a = artists[index];
                              return _buildArtistGridCard(a);
                            },
                            childCount: artists.length,
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final a = artists[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                              leading: MuxizImage.circle(
                                imageUrl: a.imageUrl,
                                size: 52,
                              ),
                              title: Text(
                                a.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.5),
                              ),
                              subtitle: const Text(
                                'Artist',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (ctx) => ArtistDetailScreen(artist: a)),
                                );
                              },
                            );
                          },
                          childCount: artists.length,
                        ),
                      ),
                  ]

                  // 3. Albums Filter
                  else if (_selectedFilter == 3) ...[
                    if (albums.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'No matching albums found',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                          ),
                        ),
                      )
                    else if (_isGridView)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 12,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final alb = albums[index];
                              return _buildAlbumGridCard(alb);
                            },
                            childCount: albums.length,
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final alb = albums[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                              leading: MuxizImage(
                                imageUrl: alb.artworkUrl,
                                width: 54,
                                height: 54,
                                borderRadius: 4,
                              ),
                              title: Text(
                                alb.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.0),
                              ),
                              subtitle: Text(
                                'Album • ${alb.artist}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => PlaylistDetailScreen(
                                      playlist: Playlist(
                                        id: alb.id,
                                        title: alb.title,
                                        description: 'Album by ${alb.artist}',
                                        coverUrl: alb.artworkUrl,
                                        creator: alb.artist,
                                        songs: alb.songs,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          childCount: albums.length,
                        ),
                      ),
                  ]

                  // 3. Playlists Filter (Default)
                  else ...[
                    if (playlists.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.queue_music_rounded, size: 54, color: AppTheme.textSecondary),
                              SizedBox(height: 12),
                              Text(
                                'Your library is empty',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Ingest songs in Studio or create playlists to get started.',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_isGridView)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 12,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final p = playlists[index];
                              return _buildPlaylistGridCard(p);
                            },
                            childCount: playlists.length,
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final p = playlists[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                              leading: MuxizImage(
                                imageUrl: p.coverUrl,
                                width: 54,
                                height: 54,
                                borderRadius: 4,
                              ),
                              title: Text(
                                p.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.0,
                                ),
                              ),
                              subtitle: Text(
                                p.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (ctx) => PlaylistDetailScreen(playlist: p)),
                                );
                              },
                              onLongPress: () => _showPlaylistContextMenu(p),
                            );
                          },
                          childCount: playlists.length,
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

  Widget _buildPlaylistGridCard(Playlist p) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (ctx) => PlaylistDetailScreen(playlist: p)),
        );
      },
      onLongPress: () => _showPlaylistContextMenu(p),
      borderRadius: BorderRadius.circular(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: MuxizImage(
              imageUrl: p.coverUrl,
              width: double.infinity,
              height: double.infinity,
              borderRadius: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            p.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
            ),
          ),
          Text(
            p.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11.0,
            ),
          ),
        ],
      ),
    );
  }

  void _showPlaylistContextMenu(Playlist p) {
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
                // Top Handle Pill
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

                // Playlist Info Header
                Row(
                  children: [
                    MuxizImage(
                      imageUrl: p.coverUrl,
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
                            p.title,
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
                            'Playlist • ${p.creator}',
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

                // Option: Share Playlist
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(Icons.share_outlined, color: Colors.white, size: 22),
                  title: const Text(
                    'Share',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: '🎵 Listen to playlist "${p.title}" on Muxiz Music App!'));
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

  Widget _buildArtistGridCard(Artist a) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (ctx) => ArtistDetailScreen(artist: a)),
        );
      },
      borderRadius: BorderRadius.circular(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: MuxizImage.circle(
                imageUrl: a.imageUrl,
                size: 88,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            a.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
            ),
          ),
          const Text(
            'Artist',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumGridCard(Album alb) {
    return InkWell(
      onTap: () {
        if (alb.songs.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => PlaylistDetailScreen(
                playlist: Playlist(
                  id: alb.id,
                  title: alb.title,
                  description: 'Album by ${alb.artist}',
                  coverUrl: alb.artworkUrl,
                  creator: alb.artist,
                  songs: alb.songs,
                ),
              ),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: MuxizImage(
              imageUrl: alb.artworkUrl,
              width: double.infinity,
              height: double.infinity,
              borderRadius: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            alb.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
            ),
          ),
          Text(
            'Album • ${alb.artist}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11.0,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Give your playlist a name', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          cursorColor: AppTheme.primaryGreen,
          decoration: const InputDecoration(
            hintText: 'My Playlist #1',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryGreen)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryGreen, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(customPlaylistsProvider.notifier).createPlaylist(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
