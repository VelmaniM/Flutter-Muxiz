enum SongActionType {
  playNow,
  playNext,
  addToQueue,
  toggleLike,
  addToPlaylist,
  download,
  removeDownload,
  goToArtist,
  goToAlbum,
  goToMovie,
  share,
  showDetails,
  removeFromPlaylist,
  removeFromLikedSongs,
  removeFromDownloads,
  removeFromQueue,
  removeFromHistory,
}

enum SongActionContext {
  standard,
  queue,
  playlist,
  likedSongs,
  downloads,
  recentlyPlayed,
  fullPlayer,
  artist,
  album,
}

class SongActionConfig {
  final SongActionContext context;
  final String? playlistId;
  final String? playlistTitle;
  final int? queueIndex;
  final bool isQueueItem;
  final VoidCallback? onCustomRemove;

  const SongActionConfig({
    this.context = SongActionContext.standard,
    this.playlistId,
    this.playlistTitle,
    this.queueIndex,
    this.isQueueItem = false,
    this.onCustomRemove,
  });

  SongActionConfig copyWith({
    SongActionContext? context,
    String? playlistId,
    String? playlistTitle,
    int? queueIndex,
    bool? isQueueItem,
    VoidCallback? onCustomRemove,
  }) {
    return SongActionConfig(
      context: context ?? this.context,
      playlistId: playlistId ?? this.playlistId,
      playlistTitle: playlistTitle ?? this.playlistTitle,
      queueIndex: queueIndex ?? this.queueIndex,
      isQueueItem: isQueueItem ?? this.isQueueItem,
      onCustomRemove: onCustomRemove ?? this.onCustomRemove,
    );
  }
}

typedef VoidCallback = void Function();
