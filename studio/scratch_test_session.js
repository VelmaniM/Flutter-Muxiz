const { google } = require('googleapis');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

async function testGoogleSession() {
  try {
    console.log('Testing Google Drive Resumable Session creation...');
    console.log('Client ID:', process.env.GOOGLE_CLIENT_ID ? 'Present' : 'Missing');
    console.log('Folder ID:', process.env.GOOGLE_DRIVE_FOLDER_ID);

    const auth = new google.auth.OAuth2(
      process.env.GOOGLE_CLIENT_ID,
      process.env.GOOGLE_CLIENT_SECRET,
      process.env.GOOGLE_REDIRECT_URI
    );

    auth.setCredentials({
      refresh_token: process.env.GOOGLE_DRIVE_REFRESH_TOKEN,
    });

    const tokenRes = await auth.getAccessToken();
    const accessToken = tokenRes.token;
    console.log('Access Token acquired:', accessToken ? 'YES (Length: ' + accessToken.length + ')' : 'NO');

    const folderId = process.env.GOOGLE_DRIVE_FOLDER_ID;
    const metadata = {
      name: 'test_song.mp3',
      parents: folderId ? [folderId] : [],
      mimeType: 'audio/mpeg',
    };

    const gRes = await fetch(
      'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable',
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json; charset=UTF-8',
          'X-Upload-Content-Type': 'audio/mpeg',
        },
        body: JSON.stringify(metadata),
      }
    );

    const uploadUrl = gRes.headers.get('location');
    console.log('Resumable Upload URL:', uploadUrl ? uploadUrl.substring(0, 80) + '...' : 'NONE');
    console.log('Status:', gRes.status);
  } catch (err) {
    console.error('Session test error:', err);
  }
}

testGoogleSession();
