import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = 'force-dynamic';

export async function GET(request) {
  try {
    const { searchParams } = new URL(request.url);
    const query = searchParams.get('query');
    const genre = searchParams.get('genre');
    const artist = searchParams.get('artist');
    const limit = parseInt(searchParams.get('limit') || '1000', 10);
    const page = parseInt(searchParams.get('page') || '1', 10);

    const where = { status: 'active' };

    if (query) {
      where.OR = [
        { title: { contains: query, mode: 'insensitive' } },
        { artistName: { contains: query, mode: 'insensitive' } },
        { movieName: { contains: query, mode: 'insensitive' } },
        { albumName: { contains: query, mode: 'insensitive' } },
      ];
    }

    if (genre && genre !== 'All') {
      where.genre = { contains: genre, mode: 'insensitive' };
    }

    if (artist) {
      where.artistName = { contains: artist, mode: 'insensitive' };
    }

    const take = limit;
    const skip = (Math.max(1, page) - 1) * take;

    const [songs, total] = await Promise.all([
      prisma.song.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take,
        skip,
        include: {
          artist: { select: { id: true, name: true, image: true } },
          album: { select: { id: true, title: true, artwork: true } },
        },
      }),
      prisma.song.count({ where }),
    ]);

    return NextResponse.json({
      success: true,
      total,
      count: songs.length,
      data: songs,
      songs,
    });
  } catch (err) {
    return NextResponse.json({ success: false, message: err.message }, { status: 500 });
  }
}
