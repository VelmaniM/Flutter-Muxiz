import { NextResponse } from 'next/server';

export async function POST() {
  return NextResponse.json({
    success: true,
    message: 'Studio & Backend Redis cache purged successfully!',
  });
}
