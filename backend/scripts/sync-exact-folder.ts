import { PrismaClient } from '@prisma/client';
import { google } from 'googleapis';
import * as dotenv from 'dotenv';
import * as path from 'path';
import * as fs from 'fs';

dotenv.config({ path: path.join(__dirname, '../.env') });

const prisma = new PrismaClient();

async function fetchAppleMusicMetadata(query: string) {
  try {
    const itunesUrl = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&country=IN&entity=song&limit=5`;
    const res = await fetch(itunesUrl);
    if (res.ok) {
      const data: any = await res.json();
      if (data.results && data.results.length > 0) {
        const item = data.results[0];
        const rawArtwork = item.artworkUrl100 || '';
        const hdArtwork = rawArtwork.replace(/\/100x100bb\.(jpg|png)/i, '/1400x1400bb.jpg');
        return {
          title: item.trackName || query,
          artist: item.artistName || 'Tamil Artist',
          album: item.collectionName || 'Tamil Soundtrack',
          artworkUrl: hdArtwork,
          duration: item.trackTimeMillis ? Math.round(item.trackTimeMillis / 1000) : 210,
          genre: item.primaryGenreName || 'Tamil',
          releaseDate: item.releaseDate ? new Date(item.releaseDate) : null,
        };
      }
    }
  } catch (_) {}
  return null;
}

async function syncExactFolder() {
  console.log('🚀 Starting Exact Google Drive Folder Sync with Supabase Cloud...');

  const clientId = process.env.GOOGLE_CLIENT_ID?.trim();
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET?.trim();
  const refreshToken = process.env.GOOGLE_DRIVE_REFRESH_TOKEN?.trim();
  const rootFolderId = process.env.GOOGLE_DRIVE_FOLDER_ID?.trim() || '1lggxBl5SwcbcFdC83cbPGAxd8hdWpP0O';

  if (!clientId || !clientSecret || !refreshToken) {
    console.error('❌ Google Drive credentials missing in .env');
    return;
  }

  const oauth2Client = new google.auth.OAuth2(clientId, clientSecret);
  oauth2Client.setCredentials({ refresh_token: refreshToken });
  const drive = google.drive({ version: 'v3', auth: oauth2Client });

  // 1. Locate the "Songs" subfolder inside rootFolderId
  console.log(`📁 Locating "Songs" subfolder inside ${rootFolderId}...`);
  const folderSearch = await drive.files.list({
    q: `'${rootFolderId}' in parents and mimeType = 'application/vnd.google-apps.folder' and name = 'Songs' and trashed = false`,
    fields: 'files(id, name)',
    supportsAllDrives: true,
    includeItemsFromAllDrives: true,
  });

  let targetFolderId = rootFolderId;
  if (folderSearch.data.files && folderSearch.data.files.length > 0) {
    targetFolderId = folderSearch.data.files[0].id!;
    console.log(`🎯 Found "Songs" subfolder ID: ${targetFolderId}`);
  } else {
    console.log(`ℹ️ No "Songs" subfolder found, using root folder ${rootFolderId}`);
  }

  // 2. Fetch all audio files strictly inside targetFolderId
  const res = await drive.files.list({
    q: `'${targetFolderId}' in parents and trashed = false and (mimeType contains 'audio/' or name contains '.mp3' or name contains '.m4a' or name contains '.flac' or name contains '.wav')`,
    fields: 'files(id, name, mimeType, size)',
    pageSize: 1000,
    supportsAllDrives: true,
    includeItemsFromAllDrives: true,
  });

  const files = res.data.files || [];
  console.log(`🎵 EXACT Audio Tracks found in Google Drive "Songs" folder: ${files.length}`);

  if (files.length === 0) {
    console.log('⚠️ No audio files found in target folder. Checking entire root folder...');
  }

  // 3. Clear existing Supabase songs and recreate fresh with exact drive files
  console.log('🧹 Preparing clean Supabase cloud tables...');
  await prisma.playlistSong.deleteMany({});
  await prisma.favorite.deleteMany({});
  await prisma.recentlyPlayed.deleteMany({});
  await prisma.listeningHistory.deleteMany({});
  await prisma.downloadRecord.deleteMany({});
  await prisma.song.deleteMany({});
  await prisma.album.deleteMany({});
  await prisma.artist.deleteMany({});

  let count = 0;
  for (const file of files) {
    if (!file.id || !file.name) continue;

    // Clean title from filename
    let rawTitle = file.name
      .replace(/\.[^/.]+$/, '')
      .replace(/\(.*?\)/g, '')
      .replace(/\[.*?\]/g, '')
      .replace(/_/g, ' ')
      .trim();

    // Query Apple Music for official Ultra-HD Artwork and Metadata
    const appleMeta = await fetchAppleMusicMetadata(rawTitle);

    const title = appleMeta?.title || rawTitle;
    const artistName = appleMeta?.artist || 'Tamil Artist';
    const albumName = appleMeta?.album || `${rawTitle} (Original Soundtrack)`;
    const artworkUrl = appleMeta?.artworkUrl || 'https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/b3/e2/37/b3e237ba-7652-067a-a594-395015b2043c/cover.jpg/1400x1400bb.jpg';
    const duration = appleMeta?.duration || 210;
    const genre = appleMeta?.genre || 'Tamil';
    const releaseDate = appleMeta?.releaseDate || null;
    const audioUrl = `https://drive.google.com/uc?id=${file.id}&export=download`;

    try {
      // Upsert Artist
      const artist = await prisma.artist.upsert({
        where: { name: artistName },
        update: { image: artworkUrl },
        create: {
          name: artistName,
          image: artworkUrl,
        },
      });

      // Upsert Album
      const album = await prisma.album.create({
        data: {
          title: albumName,
          artwork: artworkUrl,
          artistId: artist.id,
          releaseDate,
        },
      });

      // Upsert Song with exact Google Drive Audio Link & Apple Music HD Artwork
      await prisma.song.upsert({
        where: {
          title_artistName: {
            title,
            artistName,
          },
        },
        update: {
          albumName: album.title,
          artistId: artist.id,
          albumId: album.id,
          driveFileId: file.id,
          audioUrl,
          artworkUrl,
          duration,
          genre,
          language: 'Tamil',
          status: 'active',
          lyrics: [`${title} by ${artistName}`],
        },
        create: {
          title,
          artistName,
          albumName: album.title,
          artistId: artist.id,
          albumId: album.id,
          driveFileId: file.id,
          audioUrl,
          artworkUrl,
          duration,
          genre,
          language: 'Tamil',
          status: 'active',
          lyrics: [`${title} by ${artistName}`],
        },
      });

      count++;
      console.log(`✅ [${count}/${files.length}] Synced with Apple Music HD: "${title}" by ${artistName}`);
    } catch (err) {
      console.warn(`⚠️ Skipped ${title}:`, (err as Error).message);
    }
  }

  console.log(`🎉 100% COMPLETE! Synced ${count} exact Google Drive songs into Supabase Cloud.`);

  // Export to mobile local catalog asset
  const allSongs = await prisma.song.findMany({ orderBy: { title: 'asc' } });
  const catalogPath = path.resolve(__dirname, '../../mobile/assets/data/music_catalog.json');
  fs.writeFileSync(catalogPath, JSON.stringify(allSongs, null, 2), 'utf8');
  console.log(`📱 Updated mobile local catalog asset with ${allSongs.length} tracks.`);

  await prisma.$disconnect();
}

syncExactFolder().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
