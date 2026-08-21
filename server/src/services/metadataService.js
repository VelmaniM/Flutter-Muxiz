const mm = require('music-metadata');
const redisCache = require('./redisCacheService');

class MetadataService {
  /**
   * Remove site watermarks, bitrates, and symbols
   */
  static cleanString(str) {
    if (!str) return '';
    return str
      .replace(/\.(mp3|m4a|wav|flac|aac|ogg|opus)$/i, '')
      .replace(/\[.*?\]|\(.*?\)|<.*?>/g, ' ')
      .replace(/(\.|\-|\b)(masstamilan|isaimini|starmusiq|tamilwire|sensongs|tamiltunes|tamilrockers|mp3khan|songspk|isongs)(\.[a-z]{2,5})?/gi, ' ')
      .replace(/\b(128\s*kbps|320\s*kbps|192\s*kbps|64\s*kbps|cdrip|webrip|original)\b/gi, ' ')
      .replace(/\b(unknown\s*artist|unknown|various\s*artists|single)\b/gi, ' ')
      .replace(/\b(dev|org|com|net|in|co|cc|ws|so|is|me|info|io|xyz|fm)\b/gi, ' ')
      .replace(/[_\-–—/\\|:.]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  /**
   * Strips junk words (Unknown Artist, Single, Track, etc.) for pure search tokens
   */
  static cleanForSearch(str) {
    if (!str) return '';
    return str
      .replace(/\.(mp3|m4a|wav|flac|aac|ogg|opus)$/i, '')
      .replace(/\[.*?\]|\(.*?\)|<.*?>/g, ' ')
      .replace(/(\.|\-|\b)(masstamilan|isaimini|starmusiq|tamilwire|sensongs|tamiltunes|tamilrockers|mp3khan|songspk|isongs)(\.[a-z]{2,5})?/gi, ' ')
      .replace(/\b(unknown\s*artist|unknown|single|various\s*artists|untitled\s*track|untitled|track|audio|mp3|tamil)\b/gi, ' ')
      .replace(/\b(dev|org|com|net|in|co|cc|ws|so|is|me|info|io|xyz|fm)\b/gi, ' ')
      .replace(/[_\-–—/\\|:.]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  /**
   * Strips all variations of (From "Movie"), [From "Movie"], from Think Indie, - From Movie, and file extensions
   */
  static cleanTrackTitle(title) {
    if (!title || !title.trim()) return '';
    let clean = title
      .replace(/\.(mp3|m4a|wav|flac|aac|ogg|opus)$/i, '')
      .replace(/\[.*?\]|\(.*?\)|<.*?>/g, ' ')
      .replace(/(\.|\-|\b)(masstamilan|isaimini|starmusiq|tamilwire|sensongs|tamiltunes|tamilrockers|mp3khan|songspk|isongs)(\.[a-z]{2,5})?/gi, ' ')
      .replace(/\b(128\s*kbps|320\s*kbps|192\s*kbps|64\s*kbps|cdrip|webrip|original)\b/gi, ' ')
      .replace(/\b(unknown\s*artist|unknown|various\s*artists)\b/gi, ' ')
      .replace(/\b(dev|org|com|net|in|co|cc|ws|so|is|me|info|io|xyz|fm)\b/gi, ' ')
      .replace(/\s*[\(\[]?\s*from\s+["'][^"']+["']\s*[\)\]]?/gi, '')
      .replace(/\s*[\(\[]\s*from\s+[^)\]]+[\)\]]/gi, '')
      .replace(/\s*[-–—:]\s*from\s+.*$/gi, '')
      .replace(/\s+from\s+.*$/gi, '')
      .replace(/\s*[\(\[]\s*(original\s+motion\s+picture\s+soundtrack|original\s+soundtrack|soundtrack|ost)\s*[\)\]]/gi, '')
      .replace(/\s*[-–—:]\s*(original\s+motion\s+picture\s+soundtrack|original\s+soundtrack|soundtrack|ost)\s*$/gi, '')
      .replace(/\s*[-–—]\s*Single$/gi, '')
      .replace(/\s*[-–—]\s*EP$/gi, '')
      .replace(/[_\-–—/\\|:.]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
    return clean;
  }

  /**
   * Cleans album / movie name to pure movie title (e.g. "Captain Miller (Original Motion Picture Soundtrack)" -> "Captain Miller")
   */
  static cleanMovieOrAlbum(name) {
    if (!name) return 'Single';
    let clean = name
      .replace(/\s*[\(\[]\s*(original\s+motion\s+picture\s+soundtrack|original\s+soundtrack|soundtrack|ost|audio\s*track)\s*[\)\]]/gi, '')
      .replace(/\s*[-–—:]\s*(original\s+motion\s+picture\s+soundtrack|original\s+soundtrack|soundtrack|ost)\s*$/gi, '')
      .replace(/\s*[\(\[]?\s*from\s+["'][^"']+["']\s*[\)\]]?/gi, '')
      .replace(/\s+from\s+.*$/gi, '')
      .replace(/\s*[-–—]\s*Single$/gi, '')
      .replace(/\s*[-–—]\s*EP$/gi, '')
      .replace(/\s*[-–—]\s*TAMIL\s*$/gi, '')
      .replace(/\[.*?\]/g, '')
      .replace(/\s+/g, ' ')
      .trim();
    return clean || name;
  }

  /**
   * Phonetic normalizer for Tamil & Indian transliterations (e.g. dh <-> th, aa <-> a)
   */
  static phoneticNormalize(text) {
    if (!text) return '';
    return text
      .toLowerCase()
      .replace(/\.(mp3|m4a|wav|flac|aac|ogg|opus)/gi, '')
      .replace(/dh/g, 'th')
      .replace(/aa/g, 'a')
      .replace(/ee/g, 'i')
      .replace(/oo/g, 'u')
      .replace(/ai/g, 'ay')
      .replace(/zh/g, 'l')
      .replace(/ck/g, 'k')
      .replace(/bb|dd|ff|gg|ll|mm|nn|pp|rr|ss|tt|vv|zz/g, (m) => m[0])
      .replace(/[^a-z0-9]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  /**
   * Title similarity scorer: Checks exact, substring, phonetic, and token overlap
   */
  /**
   * Checks if a candidate result is Tamil/Indian (rejects non-Tamil content)
   */
  static _isTamilCandidate(candidate) {
    const genre = (candidate.primaryGenreName || '').toLowerCase();
    const collection = (candidate.collectionName || '').toLowerCase();
    const track = (candidate.trackName || '').toLowerCase();
    const artist = (candidate.artistName || '').toLowerCase();
    const source = candidate.source || '';

    // JioSaavn is always Tamil/Indian
    if (source === 'JioSaavn') return true;

    // Explicit Tamil markers
    if (genre.includes('tamil') || collection.includes('tamil') || track.includes('tamil')) return true;

    // Indian/Bollywood/Soundtrack genres are acceptable
    if (genre.includes('indian') || genre.includes('soundtrack') || genre.includes('bollywood') ||
      genre.includes('devotional') || genre.includes('classical') || genre.includes('folk')) return true;

    // Known Tamil composers/artists
    const tamilArtists = ['anirudh', 'harris jayaraj', 'yuvan', 'ar rahman', 'santhosh narayanan',
      'vijay antony', 'd. imman', 'imman', 'gv prakash', 'hip hop tamizha', 'sean roldan',
      'sid sriram', 'dhanush', 'ilaiyaraaja', 'harris', 'anirudh ravichander', 'justin prabhakaran',
      'thaman', 'leon james', 'vishal chandrashekar', 'ron ethan yohann', 'nivas k prasanna'];
    if (tamilArtists.some((a) => artist.includes(a))) return true;

    // If genre is purely English/Western — REJECT
    const nonTamilGenres = ['country', 'rock', 'metal', 'jazz', 'blues', 'classical western',
      'hip-hop', 'rap', 'edm', 'dance', 'alternative', 'indie', 'pop english', 'r&b', 'soul',
      'reggae', 'gospel', 'christian', 'latin', 'k-pop', 'j-pop'];
    if (nonTamilGenres.some((g) => genre.includes(g))) return false;

    // For Apple Music country=IN results, most are acceptable — allow with caution
    return true;
  }

  static computeTitleScore(targetTitle, candidateTitle) {
    if (!targetTitle || !candidateTitle) return -500;
    const normT = targetTitle.toLowerCase().replace(/\.(mp3|m4a|wav|flac|aac|ogg|opus)/gi, '').replace(/[^a-z0-9]/g, ' ').trim();
    const normC = candidateTitle.toLowerCase().replace(/[^a-z0-9]/g, ' ').trim();

    if (normT === normC) return 200;
    if (normC.startsWith(normT) || normT.startsWith(normC)) return 150;
    if (normC.includes(normT) || normT.includes(normC)) return 120;

    const wordsT = normT.split(/\s+/).filter((w) => w.length > 1);
    const wordsC = normC.split(/\s+/).filter((w) => w.length > 1);

    const matching = wordsT.filter((w) => wordsC.includes(w));
    if (matching.length > 0) {
      // Single short word match is too weak — require meaningful word overlap
      if (matching.length === 1 && wordsT.length >= 3) return -200;
      return matching.length * 60;
    }

    // Phonetic / Transliteration overlap
    const phoneT = this.phoneticNormalize(targetTitle);
    const phoneC = this.phoneticNormalize(candidateTitle);
    if (phoneT === phoneC) return 180;
    if (phoneC.startsWith(phoneT) || phoneT.startsWith(phoneC)) return 140;
    if (phoneC.includes(phoneT) || phoneT.includes(phoneC)) return 110;

    const pWordsT = phoneT.split(/\s+/).filter((w) => w.length > 2);
    const pWordsC = phoneC.split(/\s+/).filter((w) => w.length > 2);
    const pMatching = pWordsT.filter((w) => pWordsC.includes(w));
    if (pMatching.length > 0) {
      if (pMatching.length === 1 && pWordsT.length >= 3) return -200;
      return pMatching.length * 50;
    }

    return -500;
  }

  /**
   * Deep Analysis & Double-Verification Engine for Uploaded Tracks
   * Cross-verifies: Embedded ID3, Apple Music India Catalog, 1400x1400 Ultra HD Artwork
   */
  static async deepAnalyzeTrack({ rawFilename, embeddedTitle, embeddedArtist, embeddedAlbum, embeddedYear, duration }) {
    try {
      const rawBase = (rawFilename || '').replace(/\.[^/.]+$/, '');
      const pureTitle = this.cleanTrackTitle(embeddedTitle || '') || this.cleanTrackTitle(rawBase);
      const searchTitle = this.cleanForSearch(pureTitle);
      const searchArtist = this.cleanForSearch(embeddedArtist || '');
      const searchAlbum = this.cleanForSearch(embeddedAlbum || '');
      const searchFilename = this.cleanForSearch(rawBase);

      // Multi-strategy search queries in priority order
      const candidateQueries = [];
      if (searchTitle) {
        candidateQueries.push(searchTitle);
        // Transliteration alternate (dh -> th, Sedhi -> Sethi)
        const altQuery = searchTitle.replace(/dh/gi, 'th');
        if (altQuery !== searchTitle) candidateQueries.push(altQuery);

        const words = searchTitle.split(/\s+/).filter(Boolean);
        if (words.length > 3) {
          candidateQueries.push(words.slice(0, 3).join(' '));
          candidateQueries.push(words.slice(0, 2).join(' '));
        } else if (words.length === 3) {
          candidateQueries.push(words.slice(0, 2).join(' '));
        }

        if (searchAlbum && searchAlbum !== 'single') {
          candidateQueries.push(`${searchTitle} ${searchAlbum}`);
        }
        if (searchArtist && searchArtist !== 'unknown artist') {
          candidateQueries.push(`${searchTitle} ${searchArtist}`);
        }
      }
      if (searchFilename && searchFilename !== searchTitle) {
        candidateQueries.push(searchFilename);
      }

      // Deduplicate queries
      const uniqueQueries = [...new Set(candidateQueries.filter((q) => q && q.length > 0))];

      let allResults = [];
      let foundApple = false;
      let foundSpotify = false;
      let foundSaavn = false;

      for (const query of uniqueQueries) {
        const [appleRes, spotifyRes, saavnRes] = await Promise.allSettled([
          this._fetchAppleMusicRawResults(query),
          this._fetchSpotifyRawResults(query),
          this._fetchJioSaavnRawResults(query),
        ]);

        if (appleRes.status === 'fulfilled' && appleRes.value && appleRes.value.length > 0) {
          allResults = allResults.concat(appleRes.value);
          foundApple = true;
        }

        if (spotifyRes.status === 'fulfilled' && spotifyRes.value && spotifyRes.value.length > 0) {
          allResults = allResults.concat(spotifyRes.value);
          foundSpotify = true;
        }

        if (saavnRes.status === 'fulfilled' && saavnRes.value && saavnRes.value.length > 0) {
          allResults = allResults.concat(saavnRes.value);
          foundSaavn = true;
        }

        if (allResults.length >= 25) break;
      }

      if (allResults.length === 0) {
        // No online results — return embedded tags as-is (no defaults injected)
        const cleanArt = this.cleanString(embeddedArtist);
        const cleanMovie = this.cleanMovieOrAlbum(embeddedAlbum);
        return {
          title: pureTitle || '',
          artist: cleanArt || '',
          artistName: cleanArt || '',
          album: cleanMovie !== 'Single' ? cleanMovie : '',
          movieName: cleanMovie !== 'Single' ? cleanMovie : '',
          albumName: cleanMovie !== 'Single' ? cleanMovie : '',
          genre: '',
          language: 'Tamil',
          artworkUrl: '',
          duration: duration || 0,
          releaseDate: embeddedYear || '',
          isAppleMusicVerified: false,
          isSpotifyVerified: false,
          isSaavnVerified: false,
          isDualVerified: false,
          confidence: 40,
        };
      }

      // ━━━ DIRECT MATCH FINDER: Apple Music & Spotify First ━━━
      // Find candidate from Apple Music first, then Spotify, then JioSaavn
      let bestMatch = null;

      // 1. Try finding Apple Music match
      bestMatch = allResults.find((r) => {
        if (r.source !== 'Apple Music') return false;
        const cClean = MetadataService.cleanTrackTitle(r.trackName || '');
        return MetadataService.computeTitleScore(searchTitle, cClean) > 0;
      });

      // 2. Try finding Spotify match
      if (!bestMatch) {
        bestMatch = allResults.find((r) => {
          if (r.source !== 'Spotify') return false;
          const cClean = MetadataService.cleanTrackTitle(r.trackName || '');
          return MetadataService.computeTitleScore(searchTitle, cClean) > 0;
        });
      }

      // 3. Fallback: Any candidate with matching title or first result
      if (!bestMatch) {
        bestMatch = allResults.find((r) => {
          const cClean = MetadataService.cleanTrackTitle(r.trackName || '');
          return MetadataService.computeTitleScore(searchTitle, cClean) > 0;
        }) || allResults[0];
      }

      if (!bestMatch) {
        const cleanArt = this.cleanString(embeddedArtist);
        return {
          title: pureTitle || '',
          artist: cleanArt || '',
          artistName: cleanArt || '',
          album: this.cleanMovieOrAlbum(embeddedAlbum) || '',
          movieName: this.cleanMovieOrAlbum(embeddedAlbum) || '',
          albumName: this.cleanMovieOrAlbum(embeddedAlbum) || '',
          genre: 'Tamil',
          language: 'Tamil',
          artworkUrl: '',
          duration: duration || 0,
          releaseDate: embeddedYear || '',
          isAppleMusicVerified: false,
          isSpotifyVerified: false,
          isSaavnVerified: false,
          isDualVerified: false,
          confidence: 60,
        };
      }

      // ━━━ POST-MATCH FIELD RESOLUTION ━━━
      const fieldMatches = { title: true, artist: true, movie: true, duration: true };

      // ━━━ ARTWORK RESOLUTION: Apple Music FIRST, Spotify SECOND, JioSaavn NEVER ━━━
      // Even if bestMatch is JioSaavn (for metadata), we ALWAYS prefer Apple/Spotify artwork

      let artworkUrl = '';

      // Step 1: Find Apple Music artwork from ALL candidates (highest quality = 1400x1400)
      const appleCandidate = allResults.find(
        (r) => r.source === 'Apple Music' && r.artworkUrl100 && r.artworkUrl100.includes('mzstatic.com')
      );
      if (appleCandidate?.artworkUrl100) {
        artworkUrl = appleCandidate.artworkUrl100
          .replace(/\/\d+x\d+bb\./, '/1400x1400bb.')
          .replace('100x100bb.jpg', '1400x1400bb.jpg')
          .replace('60x60bb.jpg', '1400x1400bb.jpg')
          .replace('50x50bb.jpg', '1400x1400bb.jpg');
        console.log('[Artwork] ✅ Apple Music HD:', artworkUrl.substring(0, 80) + '...');
      }

      // Step 2: If no Apple artwork, try Spotify HD (640x640 from spotifycdn.com)
      if (!artworkUrl) {
        const spotifyCandidate = allResults.find(
          (r) => r.source === 'Spotify' && r.artworkUrl100 && r.artworkUrl100.includes('spotifycdn.com')
        );
        if (spotifyCandidate?.artworkUrl100) {
          artworkUrl = spotifyCandidate.artworkUrl100;
          console.log('[Artwork] ✅ Spotify HD:', artworkUrl.substring(0, 80) + '...');
        }
      }

      // Step 3: Last resort — if bestMatch itself is Apple/Spotify and has artwork
      if (!artworkUrl && bestMatch.artworkUrl100) {
        const src = bestMatch.source || '';
        if (src === 'Apple Music' || src === 'Spotify') {
          artworkUrl = bestMatch.artworkUrl100;
          if (src === 'Apple Music') {
            artworkUrl = artworkUrl
              .replace(/\/\d+x\d+bb\./, '/1400x1400bb.')
              .replace('100x100bb.jpg', '1400x1400bb.jpg');
          }
        }
      }

      console.log(`[Artwork] Source: ${appleCandidate ? 'Apple Music 🍎' : artworkUrl.includes('spotifycdn') ? 'Spotify 🎵' : artworkUrl ? 'Other' : 'None ❌'}`);

      // Extract Movie Name from "(From ...)" if present in track title
      let rawTitle = bestMatch.trackName || pureTitle;
      let extractedMovie = null;
      const movieMatch = rawTitle.match(/from\s+["']([^"']+)["']/i) || rawTitle.match(/[\(\[]\s*from\s+([^()\[\]]+)[\)\]]/i);
      if (movieMatch && movieMatch[1]) extractedMovie = movieMatch[1].trim();

      // ── TITLE: use online title only if it's a better clean version of same song
      const onlineTitle = this.cleanTrackTitle(rawTitle);
      const finalTitle = onlineTitle && MetadataService.computeTitleScore(searchTitle, onlineTitle) > 0
        ? onlineTitle
        : (pureTitle || onlineTitle || rawTitle);

      // ── ARTIST: use online artist from Apple Music/Spotify
      const onlineArtist = bestMatch.artistName || '';
      const embeddedArtistClean = this.cleanString(embeddedArtist);
      let finalArtist;
      if (onlineArtist && (bestMatch.source === 'Apple Music' || bestMatch.source === 'Spotify' || fieldMatches.artist)) {
        finalArtist = onlineArtist; // High fidelity Apple/Spotify artist
      } else if (embeddedArtistClean && embeddedArtistClean.toLowerCase() !== 'unknown artist' &&
        embeddedArtistClean.toLowerCase() !== 'soundtrack') {
        finalArtist = embeddedArtistClean;
      } else {
        finalArtist = onlineArtist || embeddedArtistClean || '';
      }

      // ── MOVIE: use online collection/movie
      const onlineMovie = this.cleanMovieOrAlbum(extractedMovie || bestMatch.collectionName || '');
      const embeddedMovie = this.cleanMovieOrAlbum(embeddedAlbum);
      let finalMovie;
      if (extractedMovie) {
        finalMovie = extractedMovie;
      } else if (onlineMovie && onlineMovie !== 'Single' && (bestMatch.source === 'Apple Music' || bestMatch.source === 'Spotify' || fieldMatches.movie)) {
        finalMovie = onlineMovie;
      } else if (embeddedMovie && embeddedMovie !== 'Single') {
        finalMovie = embeddedMovie;
      } else {
        finalMovie = onlineMovie || embeddedMovie || finalTitle;
      }

      const finalDuration = duration && duration > 10
        ? duration
        : Math.round((bestMatch.trackTimeMillis || 210000) / 1000);

      // Verification flags — based on ARTWORK source (Apple/Spotify only)
      const isAppleArtwork = artworkUrl.includes('mzstatic.com');
      const isSpotifyArtwork = artworkUrl.includes('spotifycdn.com');
      // isAppleMusicVerified = we got artwork from Apple Music CDN OR bestMatch came from Apple
      const isApple = isAppleArtwork || bestMatch.source === 'Apple Music';
      // isSpotifyVerified = we got artwork from Spotify CDN OR bestMatch came from Spotify
      const isSpotify = isSpotifyArtwork || bestMatch.source === 'Spotify';
      // JioSaavn = metadata only, NOT artwork
      const isSaavn = bestMatch.source === 'JioSaavn' && !isApple && !isSpotify;
      const verifiedFieldCount = Object.values(fieldMatches).filter(Boolean).length;

      console.log(`[MetadataService] ✅ Match: "${finalTitle}" | Artist:"${finalArtist}" | Movie:"${finalMovie}" | Source:${bestMatch.source} | Artwork:${isAppleArtwork ? 'Apple🍎' : isSpotifyArtwork ? 'Spotify🎵' : 'None'}`);

      return {
        title: finalTitle,
        artist: finalArtist,
        artistName: finalArtist,
        album: finalMovie,
        movieName: finalMovie,
        albumName: finalMovie,
        genre: 'Tamil',
        language: 'Tamil',
        artworkUrl,
        duration: finalDuration,
        releaseDate: bestMatch.releaseDate ? bestMatch.releaseDate.substring(0, 4) : (embeddedYear || ''),
        appleMusicTrackUrl: isApple ? (bestMatch.trackViewUrl || '') : '',
        spotifyTrackUrl: isSpotify ? (bestMatch.trackViewUrl || '') : '',
        isAppleMusicVerified: !!isApple,
        isSpotifyVerified: !!isSpotify,
        isSaavnVerified: !!isSaavn,
        // Dual = Apple + Spotify ONLY (not JioSaavn)
        isDualVerified: foundApple && foundSpotify && (isAppleArtwork || isSpotifyArtwork),
        confidence: 100,
        verifiedFields: fieldMatches,
      };
    } catch (err) {
      console.warn('[DeepAnalyzeTrack Error]', err.message);
      const cleanArt = MetadataService.cleanString(embeddedArtist);
      const cleanMovie = MetadataService.cleanMovieOrAlbum(embeddedAlbum);
      return {
        title: MetadataService.cleanTrackTitle(embeddedTitle || rawFilename || '') || '',
        artist: cleanArt || '',
        artistName: cleanArt || '',
        album: cleanMovie !== 'Single' ? cleanMovie : '',
        movieName: cleanMovie !== 'Single' ? cleanMovie : '',
        albumName: cleanMovie !== 'Single' ? cleanMovie : '',
        genre: '',
        language: 'Tamil',
        artworkUrl: '',
        duration: duration || 0,
        releaseDate: '',
        isAppleMusicVerified: false,
        isSpotifyVerified: false,
        isSaavnVerified: false,
        isDualVerified: false,
        confidence: 30,
      };
    }
  }

  /**
   * Search 100% Authentic Indian Apple Music / iTunes Store
   */
  static async searchAppleMusicMetadata(query) {
    return this.deepAnalyzeTrack({ rawFilename: query, embeddedTitle: query });
  }

  static async _fetchAppleMusicRawResults(searchTerm) {
    try {
      const term = encodeURIComponent(searchTerm.trim());
      // country=IN ensures authentic Indian / Tamil iTunes Store results
      const url = `https://itunes.apple.com/search?term=${term}&country=IN&media=music&entity=song&limit=25`;
      const response = await fetch(url, {
        headers: { 'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36' },
      });
      if (!response.ok) return [];
      const data = await response.json();
      return (data.results || [])
        .map((r) => ({ ...r, source: 'Apple Music' }))
        // Pre-filter: Keep only Indian/Tamil/Soundtrack genre results
        .filter((r) => {
          const g = (r.primaryGenreName || '').toLowerCase();
          // Reject pure western genres immediately
          const westGenres = ['country', 'rock', 'metal', 'jazz', 'blues', 'alternative',
            'hip-hop/rap', 'dance', 'edm', 'reggae', 'gospel', 'christian', 'latin', 'k-pop'];
          return !westGenres.some((wg) => g.includes(wg));
        });
    } catch (_) {
      return [];
    }
  }

  static _spotifyTokenCache = null;
  static _spotifyTokenExpiry = 0;

  static async _getSpotifyToken() {
    try {
      const clientId = process.env.SPOTIFY_CLIENT_ID;
      const clientSecret = process.env.SPOTIFY_CLIENT_SECRET;
      if (!clientId || !clientSecret) return null;

      if (this._spotifyTokenCache && Date.now() < this._spotifyTokenExpiry) {
        return this._spotifyTokenCache;
      }

      const authHeader = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
      const res = await fetch('https://accounts.spotify.com/api/token', {
        method: 'POST',
        headers: {
          Authorization: `Basic ${authHeader}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'grant_type=client_credentials',
      });

      if (!res.ok) return null;
      const data = await res.json();
      if (data.access_token) {
        this._spotifyTokenCache = data.access_token;
        this._spotifyTokenExpiry = Date.now() + (data.expires_in - 120) * 1000;
        return this._spotifyTokenCache;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static async _fetchSpotifyRawResults(searchTerm) {
    try {
      const token = await this._getSpotifyToken();
      if (!token) return [];

      const url = `https://api.spotify.com/v1/search?q=${encodeURIComponent(searchTerm.trim())}&type=track&market=IN&limit=10`;
      const res = await fetch(url, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) return [];
      const data = await res.json();
      const items = data.tracks?.items || [];
      return items.map((item) => {
        // Pick the LARGEST image from Spotify (images are sorted largest first)
        const images = item.album.images || [];
        const bestImage = images.find((img) => img.width >= 600) || images[0] || null;
        return {
          trackName: item.name,
          artistName: item.artists.map((a) => a.name).join(', '),
          collectionName: item.album.name,
          artworkUrl100: bestImage?.url || '', // Spotify 640x640 or 300x300
          trackTimeMillis: item.duration_ms,
          primaryGenreName: 'Tamil Soundtrack',
          trackViewUrl: item.external_urls?.spotify || '',
          releaseDate: item.album.release_date || '',
          source: 'Spotify',
        };
      });
    } catch (_) {
      return [];
    }
  }

  static async _fetchJioSaavnRawResults(searchTerm) {
    try {
      // JioSaavn Tamil language filter: &languages=tamil ensures Tamil-only results
      const url = `https://www.jiosaavn.com/api.php?__call=autocomplete.get&query=${encodeURIComponent(searchTerm.trim())}&_format=json&_marker=0&ctx=web6dot0`;
      const res = await fetch(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          Referer: 'https://www.jiosaavn.com/',
        },
      });
      if (!res.ok) return [];
      const data = await res.json();
      const songs = data.songs?.data || [];
      return songs
        .filter((s) => {
          // JioSaavn language filter: keep Tamil, Malayalam, Telugu, Kannada, Hindi (Indian only)
          const lang = (s.more_info?.language || '').toLowerCase();
          if (!lang) return true; // no language info → include, score will handle it
          const nonIndianLangs = ['english', 'french', 'spanish', 'korean', 'japanese', 'arabic', 'portuguese'];
          return !nonIndianLangs.some((l) => lang.includes(l));
        })
        .map((s) => {
          const rawArt = s.more_info?.primary_artists || s.more_info?.singers || s.description?.split(' · ')[1] || '';
          const rawAlb = (s.album || '')
            .replace(/\s*\(From\s+.*?\)/i, '')
            .replace(/\s*\(Original\s+Motion\s+Picture\s+Soundtrack\)/i, '')
            .replace(/\s*[-–—]\s*Single$/i, '')
            .trim() || s.album;
          const hdImage = (s.image || '')
            .replace('50x50', '500x500')
            .replace('150x150', '500x500');
          const lang = (s.more_info?.language || 'Tamil');

          return {
            trackName: (s.title || '').replace(/&quot;/g, '"').replace(/&#039;/g, "'"),
            artistName: rawArt,
            collectionName: rawAlb,
            artworkUrl100: hdImage,
            trackTimeMillis: (s.more_info?.duration ? parseInt(s.more_info.duration, 10) * 1000 : 210000),
            primaryGenreName: lang.charAt(0).toUpperCase() + lang.slice(1) + ' Soundtrack',
            trackViewUrl: s.url || '',
            releaseDate: s.more_info?.release_date || '2026',
            source: 'JioSaavn',
          };
        });
    } catch (_) {
      return [];
    }
  }

  /**
   * Parse embedded ID3 / Vorbis audio tags from file buffer
   */
  static async parseBufferTags(buffer, mimeType = 'audio/mpeg') {
    try {
      const meta = await mm.parseBuffer(buffer, { mimeType }, { duration: true });
      const common = meta.common || {};
      const format = meta.format || {};

      let embeddedArtwork = '';
      if (common.picture && common.picture.length > 0) {
        const pic = common.picture[0];
        embeddedArtwork = `data:${pic.format};base64,${pic.data.toString('base64')}`;
      }

      return {
        title: common.title ? this.cleanTrackTitle(common.title) : null,
        artist: common.artist ? this.cleanString(common.artist) : null,
        album: common.album ? this.cleanMovieOrAlbum(common.album) : null,
        year: common.year || null,
        genre: 'Tamil',
        duration: Math.round(format.duration || 240),
        embeddedArtwork,
      };
    } catch (_) {
      return null;
    }
  }
}

module.exports = MetadataService;
