import { PrismaClient } from '@prisma/client';
import * as fs from 'fs';
import * as path from 'path';

const prisma = new PrismaClient();

async function importCatalog() {
  console.log('🚀 Starting Music Catalog Seed & Migration...');

  const possiblePaths = [
    path.join(__dirname, '..', '..', 'expo music', 'src', 'constants', 'musicCatalog.json'),
    path.join('/Users/velmanikandan/expo music/src/constants/musicCatalog.json'),
  ];

  let rawCatalog: any[] = [];

  for (const p of possiblePaths) {
    if (fs.existsSync(p)) {
      try {
        const raw = fs.readFileSync(p, 'utf-8');
        rawCatalog = JSON.parse(raw);
        console.log(`📁 Loaded ${rawCatalog.length} tracks from ${p}`);
        break;
      } catch (err) {
        console.warn(`Could not read from ${p}:`, err);
      }
    }
  }

  if (rawCatalog.length === 0) {
    console.warn('⚠️ No catalog file found. Skipping migration.');
    return;
  }

  console.log(`⚡ Processing and upserting ${rawCatalog.length} songs into PostgreSQL...`);

  let count = 0;
  for (const item of rawCatalog) {
    try {
      const artistName = (item.artist || 'Unknown Artist').trim();
      const albumTitle = (item.album || 'Single').trim();
      const songTitle = (item.title || 'Untitled Track').trim();
      const artwork = item.artwork || item.artworkUrl || 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80';
      const audioUrl = item.audioUrl || '';
      const duration = typeof item.duration === 'number' ? item.duration : 180;
      const lyrics = Array.isArray(item.lyrics) ? item.lyrics : [];
      const gradient = Array.isArray(item.gradient) ? item.gradient : ['#1DB954', '#0B0C10'];

      if (!audioUrl) continue;

      // 1. Upsert Artist
      const artist = await prisma.artist.upsert({
        where: { name: artistName },
        update: {},
        create: {
          name: artistName,
          image: artwork,
        },
      });

      // 2. Upsert Album
      let album = await prisma.album.findFirst({
        where: { title: albumTitle, artistId: artist.id },
      });

      if (!album) {
        album = await prisma.album.create({
          data: {
            title: albumTitle,
            artistId: artist.id,
            artwork,
          },
        });
      }

      // 3. Upsert Song
      await prisma.song.upsert({
        where: { id: item.id || `song_${count}` },
        update: {
          title: songTitle,
          artistId: artist.id,
          albumId: album.id,
          artistName: artist.name,
          albumName: album.title,
          movieName: item.movie || item.movieName || null,
          artworkUrl: artwork,
          audioUrl,
          duration,
          genre: item.genre || 'Music',
          language: item.language || 'Tamil',
          lyrics,
          gradient,
        },
        create: {
          id: item.id || `song_${count}`,
          title: songTitle,
          artistId: artist.id,
          albumId: album.id,
          artistName: artist.name,
          albumName: album.title,
          movieName: item.movie || item.movieName || null,
          artworkUrl: artwork,
          audioUrl,
          duration,
          genre: item.genre || 'Music',
          language: item.language || 'Tamil',
          lyrics,
          gradient,
        },
      });

      count++;
      if (count % 200 === 0) {
        console.log(`✅ Seeded ${count}/${rawCatalog.length} songs...`);
      }
    } catch (songError) {
      console.warn(`Error processing song ${item.title}:`, (songError as Error).message);
    }
  }

  console.log(`🎉 Successfully seeded ${count} tracks into PostgreSQL!`);
}

importCatalog()
  .catch((e) => {
    console.error('Fatal seed error:', e);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
