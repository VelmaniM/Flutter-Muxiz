import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getDriveClient } from '@/lib/gdrive';
import { cleanRawString, cleanMovieOrAlbumName, cleanTrackTitle } from '@/lib/metadata';

export async function PUT(request, { params }) {
  try {
    const { id } = await params;
    const body = await request.json();
    const { title, artistName, movieName, albumName, genre, language, artworkUrl } = body;

    const cleanTitle = cleanTrackTitle(title);
    const cleanArtist = cleanRawString(artistName);
    const cleanMovie = cleanMovieOrAlbumName(movieName || albumName);

    const updated = await prisma.song.update({
      where: { id },
      data: {
        title: cleanTitle,
        artistName: cleanArtist,
        movieName: cleanMovie,
        albumName: cleanMovie,
        genre: genre || 'Tamil · Melody / Romantic',
        language: language || 'Tamil',
        artworkUrl: artworkUrl || null,
      },
    });

    return NextResponse.json({
      success: true,
      message: 'Song updated successfully!',
      song: updated,
    });
  } catch (err) {
    return NextResponse.json({ success: false, message: err.message }, { status: 500 });
  }
}

export async function DELETE(request, { params }) {
  try {
    const { id } = await params;
    const song = await prisma.song.findUnique({ where: { id } });

    if (song && song.driveFileId) {
      try {
        const drive = getDriveClient();
        await drive.files.delete({ fileId: song.driveFileId });
      } catch (_) {}
    }

    await prisma.song.delete({ where: { id } });

    return NextResponse.json({
      success: true,
      message: 'Song deleted successfully!',
    });
  } catch (err) {
    return NextResponse.json({ success: false, message: err.message }, { status: 500 });
  }
}
