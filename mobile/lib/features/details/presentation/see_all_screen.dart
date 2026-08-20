import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../shared/components/glass_bottom_bar.dart';
import '../../../shared/components/mini_player.dart';
import '../../../shared/components/shimmer_box.dart';
import '../../../shared/components/song_tile.dart';
import '../../../shared/models/album.dart';
import '../../../shared/models/artist.dart';
import '../../../shared/models/playlist.dart';
import '../../../shared/models/song.dart';
import '../../main_layout.dart';
import 'artist_detail_screen.dart';
import 'playlist_detail_screen.dart';

enum SeeAllType { playlists, albums, artists, songs }

class SeeAllScreen extends ConsumerStatefulWidget {
  final String title;
  final SeeAllType type;
  final List<Playlist>? playlists;
  final List<Album>? albums;
  final List<Artist>? artists;
  final List<Song>? songs;

  const SeeAllScreen({
    super.key,
    required this.title,
    required this.type,
    this.playlists,
    this.albums,
    this.artists,
    this.songs,
  });

  @override
  ConsumerState<SeeAllScreen> createState() => _SeeAllScreenState();
}

class _SeeAllScreenState extends ConsumerState<SeeAllScreen> {
  bool _isGridView = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: AppTheme.primaryGreen,
              size: 22,
            ),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildContent(context),
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

  Widget _buildContent(BuildContext context) {
    switch (widget.type) {
      case SeeAllType.playlists:
        final list = widget.playlists ?? [];
        if (_isGridView) {
          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.72,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
            ),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final p = list[i];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => PlaylistDetailScreen(playlist: p),
                    ),
                  );
                },
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
                      '${p.songs.length} songs',
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
            },
          );
        } else {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final p = list[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                leading: MuxizImage(
                  imageUrl: p.coverUrl,
                  width: 52,
                  height: 52,
                  borderRadius: 4,
                ),
                title: Text(
                  p.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.5),
                ),
                subtitle: Text(
                  'Playlist • ${p.songs.length} songs',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
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
          );
        }

      case SeeAllType.albums:
        final list = widget.albums ?? [];
        if (_isGridView) {
          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.72,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
            ),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final alb = list[i];
              final playlistEquivalent = Playlist(
                id: alb.id,
                title: alb.title,
                description: 'Movie Album • ${alb.artist}',
                coverUrl: alb.artworkUrl,
                creator: alb.artist,
                songs: alb.songs,
              );
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => PlaylistDetailScreen(playlist: playlistEquivalent),
                    ),
                  );
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
                      '${alb.songs.length} songs',
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
            },
          );
        } else {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final alb = list[i];
              final playlistEquivalent = Playlist(
                id: alb.id,
                title: alb.title,
                description: 'Movie Album • ${alb.artist}',
                coverUrl: alb.artworkUrl,
                creator: alb.artist,
                songs: alb.songs,
              );
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                leading: MuxizImage(
                  imageUrl: alb.artworkUrl,
                  width: 52,
                  height: 52,
                  borderRadius: 4,
                ),
                title: Text(
                  alb.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.5),
                ),
                subtitle: Text(
                  'Movie Album • ${alb.songs.length} songs',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
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
          );
        }

      case SeeAllType.artists:
        final list = widget.artists ?? [];
        if (_isGridView) {
          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.78,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
            ),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final a = list[i];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => ArtistDetailScreen(artist: a),
                    ),
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
                    Text(
                      '${a.topTracks.length} songs',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.0,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        } else {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final a = list[i];
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
                subtitle: Text(
                  'Artist • ${a.topTracks.length} songs',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
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
          );
        }
      case SeeAllType.songs:
        final list = widget.songs ?? [];
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8.0, bottom: 120.0),
          itemCount: list.length,
          itemBuilder: (ctx, i) {
            final song = list[i];
            return SongTile(
              song: song,
              queueContext: list,
              index: i + 1,
              showArtwork: true,
            );
          },
        );
    }
  }
}
