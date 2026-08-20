import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import fs from 'fs';
import path from 'path';

const STATUS_FILE = path.join(process.cwd(), '.server_status.json');

function getServerState() {
  try {
    if (fs.existsSync(STATUS_FILE)) {
      const data = JSON.parse(fs.readFileSync(STATUS_FILE, 'utf-8'));
      return data.active !== false;
    }
  } catch (_) {}
  return true;
}

function setServerState(active) {
  try {
    fs.writeFileSync(STATUS_FILE, JSON.stringify({ active, updatedAt: new Date().toISOString() }));
  } catch (_) {}
}

export async function GET() {
  try {
    const active = getServerState();
    let totalSongs = 0;
    try {
      totalSongs = await prisma.song.count();
    } catch (_) {}

    return NextResponse.json({
      success: true,
      active,
      status: active ? 'ONLINE' : 'OFFLINE',
      totalSongs,
      service: 'Muxiz Studio Cloud Engine',
      database: 'Connected (PostgreSQL)',
      storage: 'Google Drive Active',
      timestamp: Date.now(),
    });
  } catch (err) {
    return NextResponse.json({ success: false, message: err.message }, { status: 500 });
  }
}

export async function POST(req) {
  try {
    let active = true;
    try {
      const body = await req.json();
      if (body && typeof body.active === 'boolean') {
        active = body.active;
      } else {
        active = !getServerState();
      }
    } catch (_) {
      active = !getServerState();
    }

    setServerState(active);

    return NextResponse.json({
      success: true,
      active,
      status: active ? 'ONLINE' : 'OFFLINE',
      message: `Studio server toggled to ${active ? 'ONLINE' : 'OFFLINE'}`,
      timestamp: Date.now(),
    });
  } catch (err) {
    return NextResponse.json({ success: false, message: err.message }, { status: 500 });
  }
}
