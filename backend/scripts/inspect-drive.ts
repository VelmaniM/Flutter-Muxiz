import { google } from 'googleapis';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.join(__dirname, '../.env') });

async function checkExactFolder() {
  const clientId = process.env.GOOGLE_CLIENT_ID?.trim();
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET?.trim();
  const refreshToken = process.env.GOOGLE_DRIVE_REFRESH_TOKEN?.trim();
  const folderId = process.env.GOOGLE_DRIVE_FOLDER_ID?.trim() || '1lggxBl5SwcbcFdC83cbPGAxd8hdWpP0O';

  const oauth2Client = new google.auth.OAuth2(clientId, clientSecret);
  oauth2Client.setCredentials({ refresh_token: refreshToken });
  const drive = google.drive({ version: 'v3', auth: oauth2Client });

  console.log(`🔍 Checking Muxiz Root Folder: ${folderId}`);

  const res = await drive.files.list({
    q: `'${folderId}' in parents and trashed = false`,
    fields: 'files(id, name, mimeType)',
    supportsAllDrives: true,
    includeItemsFromAllDrives: true,
  });

  console.log('📂 Direct children of root folder:');
  const files = res.data.files || [];
  for (const f of files) {
    console.log(` - [${f.mimeType}] ${f.name} (${f.id})`);
    if (f.mimeType === 'application/vnd.google-apps.folder') {
      const subRes = await drive.files.list({
        q: `'${f.id}' in parents and trashed = false`,
        fields: 'files(id, name, mimeType)',
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
      });
      console.log(`    📁 Subfolder "${f.name}" contains ${subRes.data.files?.length || 0} files:`);
      subRes.data.files?.forEach((sub) => {
        console.log(`      🎵 ${sub.name} (${sub.id}) [${sub.mimeType}]`);
      });
    }
  }
}

checkExactFolder().catch(console.error);
