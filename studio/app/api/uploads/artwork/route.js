import { NextResponse } from 'next/server';
import { getDriveClient, bufferToStream } from '@/lib/gdrive';

export async function POST(request) {
  try {
    const formData = await request.formData();
    const file = formData.get('file');

    if (!file || typeof file === 'string') {
      return NextResponse.json({ success: false, message: 'Image file required.' }, { status: 400 });
    }

    const arrayBuffer = await file.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);

    const drive = getDriveClient();
    const folderId = process.env.GOOGLE_DRIVE_FOLDER_ID;

    const driveRes = await drive.files.create({
      requestBody: {
        name: `cover_${Date.now()}.png`,
        parents: folderId ? [folderId] : [],
        mimeType: file.type || 'image/png',
      },
      media: {
        mimeType: file.type || 'image/png',
        body: bufferToStream(buffer),
      },
      fields: 'id',
    });

    const fileId = driveRes.data.id;
    await drive.permissions.create({
      fileId,
      requestBody: { role: 'reader', type: 'anyone' },
    });

    const artworkUrl = `https://lh3.googleusercontent.com/u/0/d/${fileId}=w600-h600`;
    return NextResponse.json({ success: true, artworkUrl, fileId });
  } catch (err) {
    return NextResponse.json({ success: false, message: err.message }, { status: 500 });
  }
}
