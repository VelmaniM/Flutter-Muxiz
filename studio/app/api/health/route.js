import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export async function GET() {
  try {
    const songCount = await prisma.song.count();
    return NextResponse.json({
      status: 'ok',
      service: 'Muxiz Next.js Studio Engine',
      database: 'Connected (PostgreSQL via Prisma)',
      totalSongs: songCount,
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    return NextResponse.json(
      { status: 'error', error: err.message },
      { status: 500 }
    );
  }
}
