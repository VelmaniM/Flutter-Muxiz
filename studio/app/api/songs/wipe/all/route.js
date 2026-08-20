import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export async function DELETE() {
  try {
    const count = await prisma.song.count();
    await prisma.song.deleteMany({});
    return NextResponse.json({
      success: true,
      message: `Successfully wiped ${count} songs from database!`,
    });
  } catch (err) {
    return NextResponse.json({ success: false, message: err.message }, { status: 500 });
  }
}
