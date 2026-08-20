import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const allSongs = await prisma.song.findMany({
      select: {
        id: true,
        title: true,
        artistName: true,
        movieName: true,
        albumName: true,
        artworkUrl: true,
        audioUrl: true,
        genre: true,
        duration: true,
      },
    });

    const normalizeArtist = (raw) => {
      if (!raw) return '';
      return raw
        .replace(/(masstamilan|isaimini|starmusiq|tamiltunes|sensongs|kuttyweb|tamilwire)(\.(com|org|in|net|co|fun|cc|xyz))?/gi, '')
        .replace(/\b(masstamilan|isaimini|starmusiq|tamiltunes|sensongs|kuttyweb|tamilwire)\b/gi, '')
        .replace(/^[\s\-–—:._,]+|[\s\-–—:._,]+$/g, '')
        .trim();
    };

    const extractArtists = (raw) => {
      if (!raw) return [];
      const parts = raw
        .replace(/\s+(feat\.|ft\.|featuring|with|x|\/)\s+/gi, ', ')
        .replace(/\s+&\s+/g, ', ')
        .split(/[,;]/);

      const list = [];
      const seen = new Set();
      for (const p of parts) {
        const norm = normalizeArtist(p);
        if (norm && norm.length >= 2) {
          const lower = norm.toLowerCase();
          if (!['unknown artist', 'various artists', 'masstamilan', 'unknown'].includes(lower) && !seen.has(lower)) {
            seen.add(lower);
            list.push(norm);
          }
        }
      }
      return list.length > 0 ? list : [normalizeArtist(raw) || 'Unknown Artist'];
    };

    const artistMap = new Map();

    allSongs.forEach((song) => {
      const individualArtists = extractArtists(song.artistName);
      individualArtists.forEach((name) => {
        const key = name.toLowerCase().replace(/[^a-z0-9]/g, '');
        if (!key || key === 'unknownartist' || key === 'variousartists') return;

        if (!artistMap.has(key)) {
          artistMap.set(key, {
            id: name.toLowerCase().replace(/[^a-z0-9]/g, '_'),
            name: name,
            image: song.artworkUrl || '',
            artwork: song.artworkUrl || '',
            songCount: 1,
            songs: [song],
          });
        } else {
          const existing = artistMap.get(key);
          if (!existing.songs.some((s) => s.id === song.id)) {
            existing.songs.push(song);
            existing.songCount = existing.songs.length;
          }
          if ((!existing.image || existing.image.includes('fallback')) && song.artworkUrl) {
            existing.image = song.artworkUrl;
            existing.artwork = song.artworkUrl;
          }
        }
      });
    });

    const uniqueArtists = Array.from(artistMap.values()).sort((a, b) => b.songCount - a.songCount);

    return NextResponse.json({
      success: true,
      artists: uniqueArtists,
      data: uniqueArtists,
      songs: allSongs,
    });
  } catch (err) {
    return NextResponse.json({ success: false, message: err.message }, { status: 500 });
  }
}
