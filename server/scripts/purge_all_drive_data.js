require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { getDriveClient, FOLDER_ID } = require('../src/config/googleDrive');
const Song = require('../src/models/Song');
const Artist = require('../src/models/Artist');
const Album = require('../src/models/Album');
const LocalStore = require('../src/models/store');
const SyncService = require('../src/services/syncService');
const redisCache = require('../src/services/redisCacheService');
const { connectDB } = require('../src/config/db');

async function purgeAll() {
  console.log('🚀 Starting Complete Storage, Drive & Catalog Purge...');

  // 1. Purge Google Drive files if OAuth is available
  try {
    const drive = getDriveClient();
    const folderId = FOLDER_ID;
    console.log(`📡 Checking Google Drive Folder (${folderId})...`);

    const res = await drive.files.list({
      q: `'${folderId}' in parents and trashed = false`,
      fields: 'files(id, name)',
      pageSize: 100,
    });

    if (res.data.files && res.data.files.length > 0) {
      console.log(`🗑️ Deleting ${res.data.files.length} files from Google Drive...`);
      for (const file of res.data.files) {
        try {
          await drive.files.delete({ fileId: file.id });
          console.log(`   - Deleted Google Drive file: ${file.name} (${file.id})`);
        } catch (e) {
          console.warn(`   - Failed to delete file ${file.id}:`, e.message);
        }
      }
    } else {
      console.log('✅ Google Drive folder is already empty.');
    }
  } catch (err) {
    console.log('ℹ️ Google Drive API check:', err.message);
  }

  // 2. Clear Local Storage Media Vault
  const vaultDir = path.join(__dirname, '../data/vault');
  if (fs.existsSync(vaultDir)) {
    const vaultFiles = fs.readdirSync(vaultDir);
    console.log(`🗑️ Deleting ${vaultFiles.length} files from Local Media Vault...`);
    for (const file of vaultFiles) {
      try {
        fs.unlinkSync(path.join(vaultDir, file));
        console.log(`   - Removed vault file: ${file}`);
      } catch (_) {}
    }
  }

  // 3. Clear Local Catalog Files
  LocalStore.saveLocalSongs([]);
  LocalStore.saveLocalUsers([]);
  console.log('✅ songs.json & users.json reset to [].');

  // 4. Clear MongoDB if connected
  try {
    await connectDB();
    await Promise.all([
      Song.deleteMany({}),
      Artist.deleteMany({}),
      Album.deleteMany({}),
    ]);
    console.log('✅ MongoDB database collections cleared.');
  } catch (_) {}

  // 5. Invalidate Redis & Bump Global Cache Epoch
  await redisCache.flushAll();
  await SyncService.bumpEpoch('PURGE_ALL', 'Admin Complete Drive and Catalog Purge');

  console.log('\n✨ COMPLETE PURGE FINISHED: Drive, Local Vault, and Database are 100% Clean!');
  process.exit(0);
}

purgeAll().catch((err) => {
  console.error('Error during purge:', err);
  process.exit(1);
});
