import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getDriveClient } from '@/lib/gdrive';
import {
  cleanRawString,
  cleanMovieOrAlbumName,
  cleanTrackTitle,
  detectGenreAndMood,
} from '@/lib/metadata';

export const dynamic = 'force-dynamic';

export async function POST(request) {
  try {
    const body = await request.json();
    const {
      fileId,
      title,
      artistName,
      movieName,
      albumName,
      genre,
      language,
      artworkUrl,
      duration,
    } = body;

    if (!fileId) {
      return NextResponse.json(
        { success: false, message: 'Google Drive fileId is required.' },
        { status: 400 }
      );
    }

    const cleanTitle = cleanTrackTitle(title || 'Untitled Track');
    const cleanArtist = cleanRawString(artistName) || 'Unknown Artist';
    const cleanMovie = cleanMovieOrAlbumName(movieName || albumName) || cleanTitle;
    const cleanGenre = genre && !genre.toLowerCase().includes('masstamilan')
      ? genre.trim()
      : detectGenreAndMood(cleanTitle, cleanMovie, cleanArtist, '');
    const cleanLanguage = String(language || 'Tamil');

    // Make file publicly readable on Google Drive
    try {
      const drive = getDriveClient();
      await drive.permissions.create({
        fileId,
        requestBody: { role: 'reader', type: 'anyone' },
      });
    } catch (permErr) {
      console.warn('[Drive Permission Warning]', permErr.message);
    }

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
    const newSong = await prisma.song.create({
      data: {
        title: cleanTitle,
        artistName: cleanArtist,
        movieName: cleanMovie,
        audioUrl,
        artwork: artworkUrl || null,
        duration: duration || 240,
        genre: cleanGenre,
        language: cleanLanguage,
        artistId: artistRecord?.id || null,
        albumId: albumRecord?.id || null,
      },
    });

    return NextResponse.json({
      success: true,
      message: 'Song uploaded to Google Drive and saved to Database successfully!',
      song: newSong,
      data: newSong,
    });
  } catch (err) {
    console.error('[Upload Complete Error]', err);
    return NextResponse.json(
      { success: false, message: err.message },
      { status: 500 }
    );
  }
}
