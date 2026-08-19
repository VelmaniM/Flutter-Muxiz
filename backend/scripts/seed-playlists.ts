import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🚀 Starting App Playlists Push to PostgreSQL Database...');

  // 1. Ensure editorial/system user exists
  const editorialUser = await prisma.user.upsert({
    where: { id: 'muxiz-editorial' },
    update: {},
    create: {
      id: 'muxiz-editorial',
      email: 'editorial@muxiz.app',
      displayName: 'Muxiz Editorial',
      avatar: 'https://c.saavncdn.com/artists/Anirudh_Ravichander_500x500.jpg',
    },
  });

  // 2. Fetch all songs from PostgreSQL
  const allSongs = await prisma.song.findMany({
    where: { status: 'active' },
    orderBy: { playCount: 'desc' },
  });

  if (allSongs.length === 0) {
    console.log('❌ No songs found in database! Please seed catalog first.');
    return;
  }

  console.log(`🎵 Found ${allSongs.length} songs in database to curate playlists.`);

  function isByArtist(s: any, name: string): boolean {
    const art = (s.artistName || '').toLowerCase();
    const target = name.toLowerCase();
    return art.includes(target);
  }

  // Song trend weight calculator
  function getTrendScore(s: any): number {
    let score = 50;
    const t = (s.title || '').toLowerCase();
    const m = (s.movieName || s.albumName || '').toLowerCase();
    const a = (s.artistName || '').toLowerCase();

    if (m.includes('goat') || m.includes('greatest')) score += 100;
    if (m.includes('amaran')) score += 95;
    if (m.includes('vettaiyan')) score += 90;
    if (m.includes('leo')) score += 85;
    if (m.includes('jailer')) score += 80;
    if (t.includes('spark') || t.includes('matta') || t.includes('minnale')) score += 60;
    if (t.includes('hukum') || t.includes('badass') || t.includes('katchi')) score += 55;
    if (a.includes('anirudh')) score += 40;
    if (a.includes('rahman')) score += 35;
    if (a.includes('yuvan')) score += 30;
    return score;
  }

  const sortedByTrend = [...allSongs].sort((a, b) => getTrendScore(b) - getTrendScore(a));

  const massSongs = allSongs.filter((s) => {
    const t = (s.title || '').toLowerCase();
    const m = (s.movieName || s.albumName || '').toLowerCase();
    const g = (s.genre || '').toLowerCase();
    return (
      g.includes('dance') ||
      g.includes('soundtrack') ||
      t.includes('matta') ||
      t.includes('spark') ||
      t.includes('hukum') ||
      t.includes('badass') ||
      t.includes('naa ready') ||
      t.includes('jalabulajangu') ||
      t.includes('arabic kuthu') ||
      t.includes('aaluma') ||
      t.includes('marana') ||
      t.includes('whistle') ||
      t.includes('mass') ||
      t.includes('anthem') ||
      t.includes('theme') ||
      m.includes('goat') ||
      m.includes('leo') ||
      m.includes('jailer') ||
      m.includes('vettaiyan')
    );
  });

  const melodySongs = allSongs.filter((s) => {
    const t = (s.title || '').toLowerCase();
    const a = (s.artistName || '').toLowerCase();
    return (
      t.includes('love') ||
      t.includes('kadhal') ||
      t.includes('melody') ||
      t.includes('kanave') ||
      t.includes('uyire') ||
      t.includes('minnale') ||
      t.includes('nenj') ||
      t.includes('poo') ||
      t.includes('kadhale') ||
      a.includes('sid sriram') ||
      a.includes('pradeep kumar') ||
      a.includes('shreya ghoshal') ||
      a.includes('chinmayi') ||
      a.includes('haricharan') ||
      a.includes('shweta mohan')
    );
  });

  const anirudhSongs = allSongs.filter((s) => isByArtist(s, 'anirudh'));
  const rahmanSongs = allSongs.filter((s) => isByArtist(s, 'rahman'));
  const yuvanSongs = allSongs.filter((s) => isByArtist(s, 'yuvan'));
  const harrisSongs = allSongs.filter((s) => isByArtist(s, 'harris'));
  const santhoshSongs = allSongs.filter((s) => isByArtist(s, 'santhosh'));
  const gvSongs = allSongs.filter((s) => isByArtist(s, 'prakash'));

  const playlistsToPush = [
    {
      id: 'pl_trending_tamil_top_50',
      title: 'Trending Tamil Top 50',
      description: 'The hottest Tamil tracks trending today across India & global charts.',
      cover: sortedByTrend[0]?.artworkUrl || '',
      songs: sortedByTrend.slice(0, 30),
    },
    {
      id: 'pl_todays_top_hits',
      title: "Today's Top Hits",
      description: 'Trending Tamil bangers from Leo, The GOAT, Amaran, and Vettaiyan.',
      cover: sortedByTrend[1]?.artworkUrl || '',
      songs: sortedByTrend.slice(0, 20),
    },
    {
      id: 'pl_hot_hits_tamil',
      title: 'Hot Hits Tamil',
      description: 'Catch the biggest viral blockbusters and fresh drops in Tamil cinema.',
      cover: sortedByTrend[2]?.artworkUrl || '',
      songs: sortedByTrend.slice(2, 22),
    },
    {
      id: 'pl_kollywood_mass_anthems',
      title: 'Kollywood Mass Anthems',
      description: 'High-octane theater celebration songs from Leo, GOAT, Jailer & Vettaiyan.',
      cover: massSongs[0]?.artworkUrl || '',
      songs: massSongs.slice(0, 25),
    },
    {
      id: 'pl_tamil_mass_beats',
      title: 'Tamil Mass Beats',
      description: 'High energy gym and drive anthems by Anirudh & Santhosh Narayanan.',
      cover: massSongs[1]?.artworkUrl || '',
      songs: massSongs.slice(0, 25),
    },
    {
      id: 'pl_tamil_viral_hits',
      title: 'Tamil Viral Hits',
      description: 'The most viral tracks dominating streaming & social feeds.',
      cover: sortedByTrend[3]?.artworkUrl || '',
      songs: sortedByTrend.slice(0, 15),
    },
    {
      id: 'pl_tamil_chill_melodies',
      title: 'Tamil Chill & Melodies',
      description: 'Soulful acoustic vocals and evergreen soothing melodies.',
      cover: melodySongs[0]?.artworkUrl || '',
      songs: melodySongs.slice(0, 25),
    },
    {
      id: 'pl_melody_express',
      title: 'Melody & Romance',
      description: 'Soulful late night melodies by A.R. Rahman, Harris Jayaraj & Sid Sriram.',
      cover: melodySongs[1]?.artworkUrl || '',
      songs: melodySongs.slice(0, 25),
    },
    {
      id: 'pl_anirudh_mix',
      title: 'Anirudh Ravichander Mix',
      description: 'The best of Anirudh Ravichander, all in one place.',
      cover: anirudhSongs[0]?.artworkUrl || '',
      songs: anirudhSongs.slice(0, 30),
    },
    {
      id: 'pl_ar_rahman_mix',
      title: 'A.R. Rahman Mix',
      description: 'The best of A.R. Rahman, all in one place.',
      cover: rahmanSongs[0]?.artworkUrl || '',
      songs: rahmanSongs.slice(0, 30),
    },
    {
      id: 'pl_yuvan_classics',
      title: 'U1 Drugs 💊',
      description: 'Iconic evergreen BGM and melodies strictly by Yuvan Shankar Raja.',
      cover: yuvanSongs[0]?.artworkUrl || '',
      songs: yuvanSongs.slice(0, 30),
    },
    {
      id: 'pl_harris_mix',
      title: 'Harris Jayaraj Mix',
      description: 'The best of Harris Jayaraj, all in one place.',
      cover: harrisSongs[0]?.artworkUrl || '',
      songs: harrisSongs.slice(0, 25),
    },
    {
      id: 'pl_santhosh_mix',
      title: 'Santhosh Narayanan Mix',
      description: 'The best of Santhosh Narayanan, all in one place.',
      cover: santhoshSongs[0]?.artworkUrl || '',
      songs: santhoshSongs.slice(0, 25),
    },
    {
      id: 'pl_gv_prakash_mix',
      title: 'G.V. Prakash Kumar Mix',
      description: 'The best of G.V. Prakash Kumar, all in one place.',
      cover: gvSongs[0]?.artworkUrl || '',
      songs: gvSongs.slice(0, 25),
    },
    {
      id: 'pl_morning_motivation',
      title: 'Morning Motivation',
      description: 'Uplifting tracks to start your day with power.',
      cover: anirudhSongs[1]?.artworkUrl || '',
      songs: anirudhSongs.slice(0, 15),
    },
    {
      id: 'pl_acoustic_morning',
      title: 'Tamil Acoustic Starts',
      description: 'Soothing morning acoustic guitar and vocals.',
      cover: melodySongs[2]?.artworkUrl || '',
      songs: melodySongs.slice(0, 15),
    },
    {
      id: 'pl_afternoon_beats',
      title: 'Afternoon High Energy',
      description: 'Mass beats and high-octane chartbusters.',
      cover: massSongs[2]?.artworkUrl || '',
      songs: massSongs.slice(0, 15),
    },
    {
      id: 'pl_kollywood_drive',
      title: 'Kollywood Drive Beats',
      description: 'The ultimate driving soundtrack for your afternoon.',
      cover: sortedByTrend[4]?.artworkUrl || '',
      songs: sortedByTrend.slice(5, 20),
    },
    {
      id: 'pl_evening_unwind',
      title: 'Evening Unwind',
      description: 'Relax and groove with iconic melodies & timeless hits.',
      cover: rahmanSongs[1]?.artworkUrl || '',
      songs: rahmanSongs.slice(0, 15),
    },
    {
      id: 'pl_sunset_melodies',
      title: 'Sunset Melodies',
      description: 'Golden hour love songs and acoustic harmonies.',
      cover: melodySongs[3]?.artworkUrl || '',
      songs: melodySongs.slice(0, 15),
    },
    {
      id: 'pl_late_night_chill',
      title: 'Late Night Chill',
      description: 'Soft strings, soul vocals & soothing midnight vibes.',
      cover: melodySongs[4]?.artworkUrl || '',
      songs: melodySongs.slice(0, 15),
    },
    {
      id: 'pl_midnight_nostalgia',
      title: 'Midnight Nostalgia',
      description: 'Classic evergreen night melodies by Yuvan & Rahman.',
      cover: yuvanSongs[1]?.artworkUrl || '',
      songs: yuvanSongs.slice(0, 15),
    },
  ];

  console.log(`📦 Pushing ${playlistsToPush.length} playlists to PostgreSQL...`);

  for (const pl of playlistsToPush) {
    // Upsert Playlist
    const savedPlaylist = await prisma.playlist.upsert({
      where: { id: pl.id },
      update: {
        title: pl.title,
        description: pl.description,
        cover: pl.cover,
        isPublic: true,
      },
      create: {
        id: pl.id,
        userId: editorialUser.id,
        title: pl.title,
        description: pl.description,
        cover: pl.cover,
        isPublic: true,
      },
    });

    // Delete existing playlist_songs to avoid duplicates
    await prisma.playlistSong.deleteMany({
      where: { playlistId: savedPlaylist.id },
    });

    // Insert playlist_songs
    let position = 0;
    for (const song of pl.songs) {
      await prisma.playlistSong.create({
        data: {
          playlistId: savedPlaylist.id,
          songId: song.id,
          position: position++,
        },
      }).catch(() => {});
    }

    console.log(`✅ Pushed: "${pl.title}" with ${pl.songs.length} tracks.`);
  }

  console.log('\n🎉 ALL App Playlists Successfully Pushed & Synced to PostgreSQL Database!');
}

main()
  .catch((e) => {
    console.error('Error seeding playlists:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
