import { PrismaClient } from '@prisma/client';
import { google } from 'googleapis';
import * as fs from 'fs';
import * as path from 'path';

const prisma = new PrismaClient();

const ROOT_FOLDER_ID = '1lggxBl5SwcbcFdC83cbPGAxd8hdWpP0O';
const SONGS_FOLDER_ID = '1bbMqTYNNmLTuhQOWmFw9HxiIbiCXKQwi';
const COVERS_FOLDER_ID = '1S8-UXaDIpJnVKTqAvTlc0ngfLKn4ZbpA';
const METADATA_FOLDER_ID = '1S9b5R2r7-B-f85gK5P_zY2m04D40t3cR';

async function getDriveClient() {
  const credentialsPath = path.resolve(__dirname, '../../credentials.json');
  const tokenPath = path.resolve(__dirname, '../../token.json');

  if (!fs.existsSync(credentialsPath) || !fs.existsSync(tokenPath)) {
    console.warn('⚠️ Google Drive credentials or token not found locally, skipping Google Drive deletion.');
    return null;
  }

  const credentials = JSON.parse(fs.readFileSync(credentialsPath, 'utf8'));
  const token = JSON.parse(fs.readFileSync(tokenPath, 'utf8'));

  const { client_secret, client_id, redirect_uris } = credentials.installed || credentials.web;
  const oAuth2Client = new google.auth.OAuth2(client_id, client_secret, redirect_uris[0]);
  oAuth2Client.setCredentials(token);

  return google.drive({ version: 'v3', auth: oAuth2Client });
}

async function emptyDriveFolder(drive: any, folderId: string, folderName: string) {
  if (!drive) return;
  console.log(`🗑️ Emptying Google Drive folder: "${folderName}" (${folderId})...`);

  try {
    let pageToken: string | undefined = undefined;
    let deletedCount = 0;

    do {
      const res: any = await drive.files.list({
        q: `'${folderId}' in parents and trashed = false`,
        fields: 'nextPageToken, files(id, name)',
        pageSize: 100,
        pageToken,
      });

      const files = res.data.files || [];
      for (const file of files) {
        try {
          await drive.files.delete({ fileId: file.id });
          console.log(`   - Deleted Drive file: "${file.name}" (${file.id})`);
          deletedCount++;
        } catch (delErr) {
          console.warn(`   - Failed to delete Drive file ${file.name}: ${(delErr as Error).message}`);
        }
      }

      pageToken = res.data.nextPageToken;
    } while (pageToken);

    console.log(`✅ Emptied "${folderName}": ${deletedCount} files deleted.`);
  } catch (err) {
    console.warn(`⚠️ Error emptying Drive folder ${folderName}: ${(err as Error).message}`);
  }
}

async function performCompleteWipe() {
  console.log('🚨 [COMPLETE WIPE INITIATED] Purging all songs, albums, artists, playlists, and drive files...');

  // 1. Empty Google Drive Subfolders
  const drive = await getDriveClient();
  if (drive) {
    await emptyDriveFolder(drive, SONGS_FOLDER_ID, 'Songs');
    await emptyDriveFolder(drive, COVERS_FOLDER_ID, 'Covers');
    await emptyDriveFolder(drive, METADATA_FOLDER_ID, 'Metadata');
  }

  // 2. Truncate / Delete all PostgreSQL records in Supabase Cloud
  console.log('🗑️ Purging Supabase Cloud PostgreSQL records...');
  
  try {
    const dPlaylistSongs = await prisma.playlistSong.deleteMany({});
    console.log(`   - Deleted PlaylistSongs: ${dPlaylistSongs.count}`);

    const dPlaylists = await prisma.playlist.deleteMany({});
    console.log(`   - Deleted Playlists: ${dPlaylists.count}`);

    const dFavorites = await prisma.favorite.deleteMany({});
    console.log(`   - Deleted Favorites: ${dFavorites.count}`);

    const dRecentlyPlayed = await prisma.recentlyPlayed.deleteMany({});
    console.log(`   - Deleted RecentlyPlayed: ${dRecentlyPlayed.count}`);

    const dListeningHistory = await prisma.listeningHistory.deleteMany({});
    console.log(`   - Deleted ListeningHistory: ${dListeningHistory.count}`);

    const dDownloads = await prisma.downloadRecord.deleteMany({});
    console.log(`   - Deleted DownloadRecords: ${dDownloads.count}`);

    const dSongs = await prisma.song.deleteMany({});
    console.log(`   - Deleted Songs: ${dSongs.count}`);

    const dAlbums = await prisma.album.deleteMany({});
    console.log(`   - Deleted Albums: ${dAlbums.count}`);

    const dArtists = await prisma.artist.deleteMany({});
    console.log(`   - Deleted Artists: ${dArtists.count}`);
  } catch (dbErr) {
    console.error(`Database wipe error: ${(dbErr as Error).message}`);
  }

  // 3. Reset local catalog JSON files to empty 0 songs
  const catalogPaths = [
    path.resolve(__dirname, '../../mobile/assets/data/music_catalog.json'),
    path.resolve(__dirname, '../../dist_server/music_catalog.json'),
  ];

  for (const cPath of catalogPaths) {
    fs.writeFileSync(cPath, JSON.stringify({ songs: [] }, null, 2));
    console.log(`✅ Emptied catalog JSON: ${cPath}`);
  }

  console.log('\n==============================================================');
  console.log('🎉 [WIPE COMPLETE] Entire system reset to 0 Songs, 0 Albums, 0 Artists, 0 Playlists!');
  console.log('==============================================================\n');

  await prisma.$disconnect();
}

performCompleteWipe().catch((e) => {
  console.error(e);
  process.exit(1);
});
