import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function clearDatabase() {
  console.log('🧹 Clearing all songs, albums, artists, and playback records from database...');

  try {
    const delPlaylistSongs = await prisma.playlistSong.deleteMany({});
    console.log(`🗑️ Deleted ${delPlaylistSongs.count} playlist song links.`);

    const delFavs = await prisma.favorite.deleteMany({});
    console.log(`🗑️ Deleted ${delFavs.count} favorites.`);

    const delRecents = await prisma.recentlyPlayed.deleteMany({});
    console.log(`🗑️ Deleted ${delRecents.count} recently played.`);

    const delHistory = await prisma.listeningHistory.deleteMany({});
    console.log(`🗑️ Deleted ${delHistory.count} listening history records.`);

    const delDownloads = await prisma.downloadRecord.deleteMany({});
    console.log(`🗑️ Deleted ${delDownloads.count} download records.`);

    const delSongs = await prisma.song.deleteMany({});
    console.log(`🗑️ Deleted ${delSongs.count} songs.`);

    const delPlaylists = await prisma.playlist.deleteMany({});
    console.log(`🗑️ Deleted ${delPlaylists.count} playlists.`);

    const delAlbums = await prisma.album.deleteMany({});
    console.log(`🗑️ Deleted ${delAlbums.count} albums.`);

    const delArtists = await prisma.artist.deleteMany({});
    console.log(`🗑️ Deleted ${delArtists.count} artists.`);

    console.log('✨ Database is now 100% clean and fresh!');
  } catch (error) {
    console.error('❌ Error clearing database:', error);
  } finally {
    await prisma.$disconnect();
  }
}

clearDatabase();
