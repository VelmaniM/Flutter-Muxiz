import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { GoogleDriveService } from '../src/storage/google-drive/google-drive.service';

const SONGS_FOLDER_ID = '1bbMqTYNNmLTuhQOWmFw9HxiIbiCXKQwi';
const COVERS_FOLDER_ID = '1S8-UXaDIpJnVKTqAvTlc0ngfLKn4ZbpA';
const METADATA_FOLDER_ID = '1S9b5R2r7-B-f85gK5P_zY2m04D40t3cR';

async function emptyDriveViaNest() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const driveService = app.get(GoogleDriveService);
  const drive = driveService.getDriveClient();

  if (!drive) {
    console.error('Drive client not initialized');
    await app.close();
    return;
  }

  console.log('🗑️ [Google Drive Wipe via NestJS Service] Starting...');

  const folders = [
    { id: SONGS_FOLDER_ID, name: 'Songs' },
    { id: COVERS_FOLDER_ID, name: 'Covers' },
    { id: METADATA_FOLDER_ID, name: 'Metadata' },
  ];

  for (const folder of folders) {
    try {
      console.log(`Checking folder "${folder.name}" (${folder.id})...`);
      let pageToken: string | undefined = undefined;
      let count = 0;

      do {
        const res: any = await drive.files.list({
          q: `'${folder.id}' in parents and trashed = false`,
          fields: 'nextPageToken, files(id, name)',
          pageSize: 100,
          pageToken,
          supportsAllDrives: true,
          includeItemsFromAllDrives: true,
        });

        const files = res.data.files || [];
        for (const file of files) {
          try {
            await drive.files.delete({ fileId: file.id, supportsAllDrives: true });
            console.log(`   - Deleted Drive file: "${file.name}" (${file.id})`);
            count++;
          } catch (delErr) {
            console.warn(`   - Failed to delete Drive file ${file.name}: ${(delErr as Error).message}`);
          }
        }
        pageToken = res.data.nextPageToken;
      } while (pageToken);

      console.log(`✅ "${folder.name}" is now completely empty (${count} files deleted).`);
    } catch (err) {
      console.warn(`Could not list files in ${folder.name}: ${(err as Error).message}`);
    }
  }

  console.log('🎉 Google Drive purge complete!');
  await app.close();
}

emptyDriveViaNest().catch(console.error);
