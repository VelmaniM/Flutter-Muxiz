// Watermark patterns to remove completely
const WATERMARKS = [
  /https?:\/\/[^\s]+/gi,
  /www\.[^\s]+/gi,
  /(masstamilan|isaimini|starmusiq|tamiltunes|sensongs|kuttyweb|tamilwire|hdsongs|pagalworld|sensongsmp3|naasongs|southmp3)(\.(com|org|in|net|co|fun|cc|xyz|ws|vip|me))?/gi,
  /\[\s*(320\s*kbps|128\s*kbps|192\s*kbps|256\s*kbps|64\s*kbps|kbps|vbr|lossless|cd-rip|flac|hq|hd|original|audio|single\s*track)\s*\]/gi,
  /\(\s*(320\s*kbps|128\s*kbps|192\s*kbps|256\s*kbps|64\s*kbps|kbps|vbr|lossless|cd-rip|flac|hq|hd|original|audio|single\s*track)\s*\)/gi,
  /\[\s*\]/g,
  /\(\s*\)/g,
];

// Clean generic string
export function cleanRawString(str) {
  if (!str) return '';
  let clean = str.replace(/\.(mp3|m4a|wav|flac|aac|ogg|opus)$/i, '');
  for (const w of WATERMARKS) {
    clean = clean.replace(w, '');
  }
  return clean.replace(/_/g, ' ').replace(/\s+/g, ' ').trim();
}

// Clean movie or album name: movie and album are ALWAYS SAME
export function cleanMovieOrAlbumName(str) {
  let clean = cleanRawString(str);
  clean = clean
    .replace(/[\(\[]\s*(from\s+["']?[^"')\]]+["']?|original\s+motion\s+picture\s+soundtrack|original\s+soundtrack|ost|movie\s+songs|audio\s+songs|songs|soundtrack)\s*[\)\]]/gi, '')
    .replace(/\b(original\s+motion\s+picture\s+soundtrack|original\s+soundtrack|ost|soundtrack)\b/gi, '')
    .replace(/^[0-9]+[\s\-–—:._]+/, '')
    .replace(/[\-–—]+/g, ' ')
    .replace(/\s+/g, ' ')
    .replace(/^[\s:._,]+|[\s:._,]+$/g, '')
    .trim();
  return clean || 'Single';
}

// Clean track title: strictly NO 'From', NO '-', NO leading track numbers, pure title only
export function cleanTrackTitle(str) {
  let clean = cleanRawString(str);
  clean = clean
    .replace(/[\(\[]\s*from\s+["']?([^"')\]]+)["']?\s*[\)\]]/gi, '')
    .replace(/\bfrom\s+["']?([^"'\(\)\[\]]+)["']?/gi, '')
    .replace(/[\(\[]\s*(original\s+motion\s+picture\s+soundtrack|ost|audio\s+song|lyric\s+video|official\s+video|video\s+song|single\s+track)\s*[\)\]]/gi, '')
    .replace(/^[0-9]+[\s\-–—:._]+/, '')
    .replace(/[\-–—]+/g, ' ') // REMOVE ALL HYPHENS from song name
    .replace(/\s+/g, ' ')
    .replace(/^[\s:._,]+|[\s:._,]+$/g, '')
    .trim();
  return clean || 'Untitled Track';
}

// Pure Genre & Mood Classifier (Zero Watermarks)
export function detectGenreAndMood(title, movie, artist, primaryGenre) {
  const text = `${title || ''} ${movie || ''} ${artist || ''} ${primaryGenre || ''}`.toLowerCase();

  if (/\b(sivan|murugan|krishna|amman|sai|ganesha|devotional|bhajan|stotram|mantra|om|namah|raga|carnatic|fusion|thillana|varnam|suprabhatam|swami|temple|divine|spiritual)\b/i.test(text)) {
    return 'Classical / Devotional';
  }
  if (/\b(gaana|folk|gramathu|thiruvizha|karuppu|nattuppura|villu|parai|therukoothu|dindigul|madurai|thanjavur|morattu|gana|kothu|kuthu pattu)\b/i.test(text)) {
    return 'Folk / Gaana';
  }
  if (/\b(kuthu|dance|party|beat|danga|marana|aalu|vaathi|arabic kuthu|chellama|naa ready|jalabulajangu|badass|hukum|taana|kaavalaa|tum tum|local|thara local|dappan|chumma kizhi|sodakku|club|edm|remix|dj)\b/i.test(text)) {
    return 'Dance / Kuthu';
  }
  if (/\b(theme|mass|anthem|bgm|roar|beast|jailer|leo|vikram|master|kabali|vettaiyan|fire|thalaivar|alappara|verithanam|singam|surya|don|valimai|thunivu|thuppakki|kaththi|hero|power|clash|war|fighter|devara|kalki|salaar|pushpa|action)\b/i.test(text)) {
    return 'Mass / Energetic';
  }
  if (/\b(sad|pirivu|valigal|kaneer|alone|pain|heartbreak|maranthu|po nee po|kanave|unnaley|vazhi|thaniyaga|theeradha|azhuvatha|vidai|marakkuma|thaaye|amma|appa|kannaana kanne|chinnachiru|aararo|lullaby|emotional|tears|grief)\b/i.test(text)) {
    return 'Soulful / Sad';
  }
  if (/\b(lofi|lo-fi|acoustic|chill|unplugged|slowed|reverb|midnight|breeze|coffee|relax|peaceful|calm|ambient|night|rain|moonlight)\b/i.test(text)) {
    return 'Chill / Lo-Fi';
  }
  if (/\b(hip hop|hiphop|rap|trap|urban|aadhi|yogi b|mc|rhyme|flow|street|cypher|drill|bloody sweet|hip-hop)\b/i.test(text)) {
    return 'Hip-Hop / Rap';
  }
  return 'Melody / Romantic';
}

// Filename metadata parser
export function parseFilenameMetadata(filename) {
  let name = cleanRawString(filename);
  let title = name;
  let movieName = '';
  let artist = 'Unknown Artist';

  const fromMatch = name.match(/^(.+?)\s+[\(\[]\s*from\s+["']?([^"')\]]+)["']?\s*[\)\]]/i);
  if (fromMatch) {
    title = cleanTrackTitle(fromMatch[1]);
    movieName = cleanMovieOrAlbumName(fromMatch[2]);
    return { title, movieName, albumName: movieName, artist };
  }

  const parts = name.split(/\s+-\s+/);
  if (parts.length === 2) {
    movieName = cleanMovieOrAlbumName(parts[0]);
    title = cleanTrackTitle(parts[1]);
  } else if (parts.length >= 3) {
    movieName = cleanMovieOrAlbumName(parts[0]);
    title = cleanTrackTitle(parts[1]);
    artist = cleanRawString(parts[2]);
  } else {
    title = cleanTrackTitle(name);
    movieName = title;
  }

  return {
    title: title || 'Untitled Track',
    movieName: movieName || title,
    albumName: movieName || title,
    artist: artist || 'Unknown Artist',
  };
}

// 100% Apple Music Ultra-HD Metadata & Artwork Fetcher
export async function fetchAppleMusicMetadata(rawTitle, rawMovie, rawArtist) {
  const cleanT = cleanTrackTitle(rawTitle);
  const cleanM = cleanMovieOrAlbumName(rawMovie);
  const cleanA = cleanRawString(rawArtist);

  const queries = [
    `${cleanT} ${cleanM}`.trim(),
    `${cleanT} ${cleanA !== 'Unknown Artist' ? cleanA : 'Tamil'}`.trim(),
    cleanT,
    cleanM,
  ].filter(Boolean);

  for (const q of queries) {
    try {
      const res = await fetch(
        `https://itunes.apple.com/search?term=${encodeURIComponent(q)}&country=IN&media=music&entity=song&limit=5`
      );
      if (!res.ok) continue;
      const data = await res.json();

      if (data.results && data.results.length > 0) {
        // Find best match
        const match = data.results[0];
        const rawArt = match.artworkUrl100 || match.artworkUrl60 || match.artworkUrl30;
        const appleArtwork = rawArt
          ? rawArt.replace('/100x100bb', '/600x600bb').replace('/60x60bb', '/600x600bb')
          : '';

        const matchedTitle = cleanTrackTitle(match.trackName || cleanT);
        const matchedMovie = cleanMovieOrAlbumName(match.collectionName || cleanM || matchedTitle);
        const matchedArtist = cleanRawString(match.artistName || cleanA || 'Unknown Artist');
        const matchedGenre = detectGenreAndMood(matchedTitle, matchedMovie, matchedArtist, match.primaryGenreName);

        return {
          title: matchedTitle,
          movieName: matchedMovie,
          albumName: matchedMovie,
          artistName: matchedArtist,
          genre: matchedGenre,
          artworkUrl: appleArtwork,
          duration: match.trackTimeMillis ? Math.round(match.trackTimeMillis / 1000) : 180,
        };
      }
    } catch (_) {}
  }

  return null;
}
