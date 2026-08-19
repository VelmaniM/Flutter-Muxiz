import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function resetDatabase() {
  console.log('🧹 Clearing all songs, albums, and playlists from PostgreSQL...');
  try {
    await prisma.listeningHistory.deleteMany();
    await prisma.recentlyPlayed.deleteMany();
    await prisma.favorite.deleteMany();
    await prisma.downloadRecord.deleteMany();
    await prisma.playlistSong.deleteMany();
    await prisma.playlist.deleteMany();
    await prisma.song.deleteMany();
    await prisma.album.deleteMany();
    await prisma.artist.deleteMany();

    console.log('✨ PostgreSQL Database cleared! Total Songs: 0');
  } catch (e) {
    console.warn('Note on DB clear:', (e as Error).message);
  } finally {
    await prisma.$disconnect();
  }
}

resetDatabase();
