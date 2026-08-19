import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function checkDb() {
  const songCount = await prisma.song.count();
  const artistCount = await prisma.artist.count();
  const albumCount = await prisma.album.count();
  const playlistCount = await prisma.playlist.count();

  console.log(`📊 Current DB Counts:`);
  console.log(`   - Songs: ${songCount}`);
  console.log(`   - Artists: ${artistCount}`);
  console.log(`   - Albums: ${albumCount}`);
  console.log(`   - Playlists: ${playlistCount}`);

  if (songCount > 0 || artistCount > 0 || albumCount > 0 || playlistCount > 0) {
    console.log('🗑️ Purging remaining records in DB...');
    await prisma.playlistSong.deleteMany({});
    await prisma.playlist.deleteMany({});
    await prisma.favorite.deleteMany({});
    await prisma.recentlyPlayed.deleteMany({});
    await prisma.listeningHistory.deleteMany({});
    await prisma.downloadRecord.deleteMany({});
    await prisma.song.deleteMany({});
    await prisma.album.deleteMany({});
    await prisma.artist.deleteMany({});
    console.log('✅ DB tables completely emptied (0 records)!');
  } else {
    console.log('✅ DB is already 100% empty (0 songs, 0 artists, 0 albums)!');
  }

  await prisma.$disconnect();
}

checkDb().catch(console.error);
