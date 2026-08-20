import { NextResponse } from 'next/server';
import { google } from 'googleapis';

export const dynamic = 'force-dynamic';

export async function POST(request) {
  try {
    const { fileName, mimeType } = await request.json();

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

    if (!accessToken) {
      return NextResponse.json(
        { success: false, message: 'Failed to acquire Google Drive access token' },
        { status: 500 }
      );
    }

    const folderId = process.env.GOOGLE_DRIVE_FOLDER_ID;
    const metadata = {
      name: fileName || 'song.mp3',
      parents: folderId ? [folderId] : [],
      mimeType: mimeType || 'audio/mpeg',
    };

    // Request direct resumable session URI from Google
    const gRes = await fetch(
      'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable',
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json; charset=UTF-8',
          'X-Upload-Content-Type': mimeType || 'audio/mpeg',
        },
        body: JSON.stringify(metadata),
      }
    );

    const uploadUrl = gRes.headers.get('location');

    if (!uploadUrl) {
      const errText = await gRes.text();
      return NextResponse.json(
        { success: false, message: `Google Drive error: ${errText}` },
        { status: 500 }
      );
    }

    return NextResponse.json({
      success: true,
      uploadUrl,
    });
  } catch (err) {
    console.error('[Resumable Session Error]', err);
    return NextResponse.json(
      { success: false, message: err.message },
      { status: 500 }
    );
  }
}
