import { NextResponse } from 'next/server';
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

export async function POST() {
  try {
    const newState = !getServerState();
    setServerState(newState);

    return NextResponse.json({
      success: true,
      active: newState,
      status: newState ? 'ONLINE' : 'OFFLINE',
      message: `Studio server toggled to ${newState ? 'ONLINE' : 'OFFLINE'}`,
      timestamp: Date.now(),
    });
  } catch (err) {
    return NextResponse.json({ success: false, message: err.message }, { status: 500 });
  }
}
