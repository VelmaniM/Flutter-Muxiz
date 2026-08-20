import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export async function PUT(request, { params }) {
  try {
    const { id } = await params;
    const body = await request.json();
    const { name, bio, imageUrl } = body;

    const updated = await prisma.artist.update({
      where: { id },
      data: {
        name: name ? String(name).trim() : undefined,
        bio: bio !== undefined ? String(bio).trim() : undefined,
        image: (imageUrl || image) !== undefined ? String(imageUrl || image).trim() : undefined,
      },
    });

    return NextResponse.json({
      success: true,
      message: 'Artist profile updated successfully!',
      artist: updated,
    });
  } catch (err) {
    return NextResponse.json({ success: false, message: err.message }, { status: 500 });
  }
}

export async function DELETE(request, { params }) {
  try {
    const { id } = await params;
    await prisma.artist.delete({ where: { id } });
    return NextResponse.json({ success: true, message: 'Artist deleted successfully!' });
  } catch (err) {
    return NextResponse.json({ success: false, message: err.message }, { status: 500 });
  }
}
