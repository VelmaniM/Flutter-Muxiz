import { PrismaClient } from '@prisma/client';
import * as dotenv from 'dotenv';
import * as path from 'path';
import * as fs from 'fs';

dotenv.config({ path: path.join(__dirname, '../.env') });

const prisma = new PrismaClient();

function normalizeTitle(title: string): string {
  return title
    .toLowerCase()
    .replace(/\(.*?\)/g, '')
    .replace(/\[.*?\]/g, '')
    .replace(/[^a-z0-9]/g, '')
    .trim();
}

async function deduplicateAndPerfectDatabase() {
  console.log('🧹 Starting Database Deduplication & Clean-up...');

  const allSongs = await prisma.song.findMany({
    orderBy: { createdAt: 'desc' },
  });

  console.log(`📊 Found ${allSongs.length} total song records currently in Supabase.`);

  const seen = new Map<string, string>(); // normalizedKey -> songId to KEEP
  const duplicateIds: string[] = [];

  for (const song of allSongs) {
    const key = normalizeTitle(song.title);
    if (seen.has(key)) {
      duplicateIds.push(song.id);
      console.log(`🗑️ Identified duplicate: "${song.title}" (${song.id})`);
    } else {
      seen.set(key, song.id);
    }
  }

  if (duplicateIds.length > 0) {
    console.log(`🔥 Deleting ${duplicateIds.length} duplicate song entries...`);
    await prisma.playlistSong.deleteMany({ where: { songId: { in: duplicateIds } } });
    await prisma.favorite.deleteMany({ where: { songId: { in: duplicateIds } } });
    await prisma.recentlyPlayed.deleteMany({ where: { songId: { in: duplicateIds } } });
    await prisma.listeningHistory.deleteMany({ where: { songId: { in: duplicateIds } } });
    await prisma.downloadRecord.deleteMany({ where: { songId: { in: duplicateIds } } });
    await prisma.song.deleteMany({ where: { id: { in: duplicateIds } } });
  }

  // Remove any orphan albums or artists
  const songsLeft = await prisma.song.findMany({
    include: { artist: true, album: true },
    orderBy: { title: 'asc' },
  });

  console.log(`✨ PERFECT! Exactly ${songsLeft.length} unique master tracks in Supabase.`);

  // Export to mobile catalog
  const catalogPath = path.resolve(__dirname, '../../mobile/assets/data/music_catalog.json');
  fs.writeFileSync(catalogPath, JSON.stringify(songsLeft, null, 2), 'utf8');
  console.log(`📱 Exported ${songsLeft.length} clean tracks to mobile/assets/data/music_catalog.json`);

  console.log('\n📜 COMPLETE UNIQUE TRACK LIST:');
  songsLeft.forEach((s, i) => {
    console.log(`${i + 1}. "${s.title}" — ${s.artistName} [${s.albumName}]`);
  });

  await prisma.$disconnect();
}

deduplicateAndPerfectDatabase().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
