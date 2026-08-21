import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../core/actions/song_action_controller.dart';
import '../../core/actions/song_action_models.dart';
import '../../core/storage/download_manager.dart';
import '../../core/storage/local_storage.dart';
import '../models/song.dart';
import 'shimmer_box.dart';

void showSongActionModal(
  BuildContext context,
  WidgetRef ref,
  Song song, {
  SongActionConfig config = const SongActionConfig(),
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1E1E1E),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SongActionModal(song: song, config: config),
  );
}

class SongActionModal extends ConsumerWidget {
  final Song song;
  final SongActionConfig config;

  const SongActionModal({
    super.key,
    required this.song,
    this.config = const SongActionConfig(),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionCtrl = ref.watch(songActionControllerProvider);
    final downloadMgr = ref.watch(downloadManagerProvider);
    final isDownloaded = downloadMgr.isDownloaded(song.id) || song.isDownloaded;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Song Header with Artwork, Title, Artist, and Badges
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Row(
                  children: [
                    MuxizImage(
                      imageUrl: song.artworkUrl,
                      width: 56,
                      height: 56,
                      borderRadius: 8,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isDownloaded)
                      const Padding(
                        padding: EdgeInsets.only(left: 6.0),
                        child: Icon(Icons.arrow_circle_down_rounded, color: AppTheme.primaryGreen, size: 20),
                      ),
                  ],
                ),
              ),

              const Divider(color: Color(0xFF2E2E2E), height: 16),

              // --- PRIMARY ACTIONS ---

              // 1. Play Next
              if (config.context != SongActionContext.queue || config.queueIndex != 0)
                ListTile(
                  leading: const Icon(Icons.playlist_play_rounded, color: Colors.white, size: 24),
                  title: const Text('Play Next', style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    actionCtrl.playNext(context, song);
                  },
                ),

              // 2. Add to Queue
              if (config.context != SongActionContext.queue)
                ListTile(
                  leading: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 24),
                  title: const Text('Add to Queue', style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    actionCtrl.addToQueue(context, song);
                  },
                ),

              // 3. Like / Unlike (Liked Songs)
              Builder(
                builder: (ctx) {
                  final isFav = ref.watch(favoritesProvider).contains(song.id);
                  return ListTile(
                    leading: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFav ? AppTheme.primaryGreen : Colors.white,
                      size: 24,
                    ),
                    title: Text(
                      isFav ? 'Remove from Liked Songs' : 'Save to Liked Songs',
                      style: TextStyle(
                        color: isFav ? AppTheme.primaryGreen : Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(favoritesProvider.notifier).toggle(song);
                    },
                  );
                },
              ),

              // 4. Add to Playlist
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded, color: Colors.white, size: 24),
                title: const Text('Add to Playlist', style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _showAddToPlaylistModal(context, ref, song);
                },
              ),

              // 5. Download / Remove Download
              ListTile(
                leading: Icon(
                  isDownloaded ? Icons.delete_outline_rounded : Icons.arrow_circle_down_rounded,
                  color: isDownloaded ? Colors.redAccent : Colors.white,
                  size: 24,
                ),
                title: Text(
                  isDownloaded ? 'Remove Download' : 'Download for Offline Listening',
                  style: TextStyle(
                    color: isDownloaded ? Colors.redAccent : Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  actionCtrl.downloadOrRemove(context, song);
                },
              ),

              // --- CONTEXTUAL REMOVAL ACTIONS ---

              // Remove from Custom Playlist
              if (config.context == SongActionContext.playlist && config.playlistId != null)
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 24),
                  title: const Text(
                    'Remove from this Playlist',
                    style: TextStyle(color: Colors.redAccent, fontSize: 14.5, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    actionCtrl.removeFromPlaylist(context, song, config.playlistId!, playlistTitle: config.playlistTitle);
                  },
                ),

              // Remove from Queue
              if (config.context == SongActionContext.queue && config.queueIndex != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
                  title: const Text(
                    'Remove from Queue',
                    style: TextStyle(color: Colors.redAccent, fontSize: 14.5, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    actionCtrl.removeFromQueue(context, config.queueIndex!, song);
                  },
                ),

              const Divider(color: Color(0xFF2E2E2E), height: 16),

              // --- SECONDARY NAVIGATION & INFO ACTIONS ---

              // 6. Go to Artist
              if (song.artist.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 24),
                  title: Text('Go to Artist (${song.artist})', style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    actionCtrl.goToArtist(context, song);
                  },
                ),

              // 7. Go to Album
              if (song.album.isNotEmpty && song.album.toLowerCase() != 'single')
                ListTile(
                  leading: const Icon(Icons.album_outlined, color: Colors.white, size: 24),
                  title: Text('Go to Album (${song.album})', style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    actionCtrl.goToAlbum(context, song);
                  },
                ),

              // 8. Share
              ListTile(
                leading: const Icon(Icons.share_rounded, color: Colors.white, size: 24),
                title: const Text('Share Song', style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  actionCtrl.shareSong(context, song);
                },
              ),

              // 9. Song Details
              ListTile(
                leading: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 24),
                title: const Text('Song Details', style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  actionCtrl.showSongDetails(context, song);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Add to Playlist Modal with Search & Inline Creation ---
  void _showAddToPlaylistModal(BuildContext context, WidgetRef ref, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _AddToPlaylistSheet(song: song);
      },
    );
  }
}

class _AddToPlaylistSheet extends ConsumerStatefulWidget {
  final Song song;

  const _AddToPlaylistSheet({required this.song});

  @override
  ConsumerState<_AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends ConsumerState<_AddToPlaylistSheet> {
  final TextEditingController _filterController = TextEditingController();
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _filterController.addListener(() {
      setState(() {
        _filter = _filterController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customPlaylists = ref.watch(customPlaylistsProvider);
    final filtered = _filter.isEmpty
        ? customPlaylists
        : customPlaylists.where((p) => p.title.toLowerCase().contains(_filter)).toList();

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
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
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add to Playlist',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Search Filter Bar
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _filterController,
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                decoration: const InputDecoration(
                  hintText: 'Search playlists',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.white38, size: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // + New Playlist Button
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.add_rounded, color: AppTheme.primaryGreen, size: 26),
              ),
              title: const Text(
                'New Playlist',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
              ),
              subtitle: const Text(
                'Create a new playlist and add this song',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              onTap: () {
                _showCreatePlaylistDialog(context, ref, widget.song);
              },
            ),

            const Divider(color: Color(0xFF2E2E2E), height: 16),

            // Playlists List
            if (filtered.isEmpty && _filter.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    'No playlists match search',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
              )
            else if (customPlaylists.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    'No custom playlists yet.\nTap "New Playlist" above to create one!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (ctx, index) {
                    final playlist = filtered[index];
                    final containsSong = playlist.songs.any((s) => s.id == widget.song.id);

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: MuxizImage(
                        imageUrl: playlist.coverUrl,
                        width: 44,
                        height: 44,
                        borderRadius: 4,
                      ),
                      title: Text(
                        playlist.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Playlist',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      trailing: Icon(
                        containsSong ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                        color: containsSong ? AppTheme.primaryGreen : Colors.white38,
                        size: 22,
                      ),
                      onTap: () async {
                        final actionCtrl = ref.read(songActionControllerProvider);
                        if (containsSong) {
                          actionCtrl.showFeedback(context, 'Already in ${playlist.title}');
                        } else {
                          await ref.read(customPlaylistsProvider.notifier).toggleSongInPlaylist(playlist.id, widget.song);
                          if (context.mounted) {
                            actionCtrl.showFeedback(context, 'Added "${widget.song.title}" to ${playlist.title}');
                          }
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref, Song song) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        title: const Text('Give your playlist a name', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'My Playlist',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryGreen)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryGreen, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final created = await ref.read(customPlaylistsProvider.notifier).createPlaylist(name, initialSong: song);
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                }
                if (context.mounted) {
                  ref.read(songActionControllerProvider).showFeedback(
                    context,
                    'Created "${created.title}" and added "${song.title}"',
                  );
                }
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
