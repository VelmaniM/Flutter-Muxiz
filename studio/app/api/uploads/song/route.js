import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getDriveClient, bufferToStream } from '@/lib/gdrive';
import {
  cleanRawString,
  cleanMovieOrAlbumName,
  cleanTrackTitle,
  detectGenreAndMood,
} from '@/lib/metadata';

export const dynamic = 'force-dynamic';

export async function POST(request) {
  try {
    const formData = await request.formData();
    const file = formData.get('file');

    if (!file || typeof file === 'string') {
      return NextResponse.json(
        { success: false, message: 'Audio file is required.' },
        { status: 400 }
      );
    }

    const title = formData.get('title') || file.name;
    const artistName = formData.get('artistName') || 'Unknown Artist';
    const movieName = formData.get('movieName') || formData.get('albumName') || 'Single';
    const rawGenre = formData.get('genre') || '';
    const language = formData.get('language') || 'Tamil';
    const artworkUrl = formData.get('artworkUrl') || null;

    const cleanTitle = cleanTrackTitle(title);
    const cleanArtist = cleanRawString(artistName) || 'Unknown Artist';
    const cleanMovie = cleanMovieOrAlbumName(movieName) || cleanTitle;
    const cleanGenre = rawGenre && !rawGenre.toLowerCase().includes('masstamilan')
      ? rawGenre.trim()
      : detectGenreAndMood(cleanTitle, cleanMovie, cleanArtist, '');
    const cleanLanguage = String(language || 'Tamil');

    // Convert file to Buffer
    const arrayBuffer = await file.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);

    // Stream upload directly to Google Drive
    const drive = getDriveClient();
    const folderId = process.env.GOOGLE_DRIVE_FOLDER_ID;

    const driveRes = await drive.files.create({
      requestBody: {
        name: `${cleanTitle}.mp3`,
        parents: folderId ? [folderId] : [],
        mimeType: file.type || 'audio/mpeg',
      },
      media: {
        mimeType: file.type || 'audio/mpeg',
        body: bufferToStream(buffer),
      },
      fields: 'id, name, webViewLink, webContentLink',
    });

    const fileId = driveRes.data.id;
    await drive.permissions.create({
      fileId,
      requestBody: { role: 'reader', type: 'anyone' },
    });

    const audioUrl = `https://drive.google.com/uc?id=${fileId}&export=download`;

    // Dynamic Artist tokenization & profile creation
    let artistRecord = await prisma.artist.findFirst({
      where: { name: { equals: cleanArtist, mode: 'insensitive' } },
    });
    if (!artistRecord && cleanArtist !== 'Unknown Artist') {
      artistRecord = await prisma.artist.create({
        data: {
          name: cleanArtist,
          image: artworkUrl || null,
          bio: `Celebrated Tamil artist in Muxiz.`,
        },
      });
    }

    // Auto-create / Connect Album in DB
    let albumRecord = null;
    if (cleanMovie && cleanMovie !== 'Single') {
      albumRecord = await prisma.album.findFirst({
        where: { title: { equals: cleanMovie, mode: 'insensitive' } },
      });
      if (!albumRecord) {
        albumRecord = await prisma.album.create({
          data: {
            title: cleanMovie,
            artistId: artistRecord?.id || null,
            artwork: artworkUrl || null,
          },
        });
      }
    }

    // Save Song in PostgreSQL Database
    const savedSong = await prisma.song.create({
      data: {
        title: cleanTitle,
        artistName: cleanArtist,
        albumName: cleanMovie,
        movieName: cleanMovie,
        artistId: artistRecord?.id || null,
        albumId: albumRecord?.id || null,
        genre: cleanGenre,
        language: cleanLanguage,
        audioUrl,
        artworkUrl: artworkUrl ? String(artworkUrl) : null,
        driveFileId: fileId,
      },
    });

    return NextResponse.json(
      {
        success: true,
        message: `Song "${cleanTitle}" uploaded and saved successfully!`,
        song: savedSong,
        data: savedSong,
      },
      { status: 201 }
    );
  } catch (err) {
    console.error('Next.js upload error:', err);
    return NextResponse.json(
      { success: false, message: err.message || 'Upload failed' },
      { status: 500 }
    );
  }
}
