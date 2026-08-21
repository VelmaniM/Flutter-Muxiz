import React, { useState, useRef } from 'react';
import {
  UploadCloud,
  CheckCircle2,
  AlertCircle,
  Search,
  Music,
  X,
  Sparkles,
  Check,
  ExternalLink,
  ShieldCheck,
  Play,
  Pause,
  RefreshCw,
  Trash2,
  Image as ImageIcon,
} from 'lucide-react';
import * as mm from 'music-metadata-browser';
import { api } from '../services/api';

const ultraSanitize = (text) => {
  if (!text) return '';
  let s = text.replace(/\.(mp3|m4a|wav|flac|aac|ogg|opus)$/i, '');

  // 1. Convert underscores & slashes to spaces
  s = s.replace(/[_/\\|]/g, ' ');

  // 2. Remove site and domain patterns (bracketed or standalone)
  s = s.replace(/\[\s*(masstamilan|isaimini|starmusiq|tamilwire|sensongs|tamiltunes|tamilrockers|mp3khan|songspk|isongs)[^\]]*\]/gi, ' ');
  s = s.replace(/\(\s*(masstamilan|isaimini|starmusiq|tamilwire|sensongs|tamiltunes|tamilrockers|mp3khan|songspk|isongs)[^\)]*\)/gi, ' ');
  s = s.replace(/\[\s*[a-z0-9\-_.]+\.(com|dev|org|net|in|co|cc|ws|so|is|me|info|io|xyz|fm)\s*\]/gi, ' ');
  s = s.replace(/\(\s*[a-z0-9\-_.]+\.(com|dev|org|net|in|co|cc|ws|so|is|me|info|io|xyz|fm)\s*\)/gi, ' ');

  s = s.replace(/(\.|\-|\b)(masstamilan|isaimini|starmusiq|tamilwire|sensongs|tamiltunes|tamilrockers|mp3khan|songspk|isongs)(\.[a-z]{2,5})?/gi, ' ');
  s = s.replace(/\b(128\s*kbps|320\s*kbps|192\s*kbps|64\s*kbps|vbr|cbr|cdrip|webrip|hq|hd|kbps|original)\b/gi, ' ');
  s = s.replace(/\b(unknown\s*artist|unknown|various\s*artists)\b/gi, ' ');
  s = s.replace(/\b(dev|org|com|net|in|co|cc|ws|so|is|me|info|io|xyz|fm)\b/gi, ' ');

  // 3. Remove leading track numbers like "01 - ", "02. ", "1 - "
  s = s.replace(/^\s*0\d[\s.\-_–—:]+/g, ' ').replace(/^\s*\d[\s.\-_–—:]+/g, ' ');

  // 4. Remove (From "Movie"), [From "Movie"], from Think Indie
  s = s.replace(/\s*[\(\[]?\s*from\s+["'][^"']+["']\s*[\)\]]?/gi, ' ');
  s = s.replace(/\s*[\(\[]\s*from\s+[^)\]]+[\)\]]/gi, ' ');
  s = s.replace(/\s*[-–—:]\s*from\s+.*$/gi, ' ');
  s = s.replace(/\s+from\s+.*$/gi, ' ');
  s = s.replace(/\s*[\(\[]\s*(original\s+motion\s+picture\s+soundtrack|original\s+soundtrack|soundtrack|ost)\s*[\)\]]/gi, ' ');
  s = s.replace(/\s*[-–—:]\s*(original\s+motion\s+picture\s+soundtrack|original\s+soundtrack|soundtrack|ost)\s*$/gi, ' ');
  s = s.replace(/\s*[-–—]\s*Single$/gi, ' ');
  s = s.replace(/\s*[-–—]\s*EP$/gi, ' ');
  s = s.replace(/\[.*?\]/g, ' ');

  // 5. Clean up leading/trailing symbols, dashes, and extra whitespace
  s = s.replace(/^[\s\-_–—:,|/\\.]+|[\s\-_–—:,|/\\.]+$/g, '');
  s = s.replace(/\s*[-–—:]+\s*$/g, '');
  s = s.replace(/^\s*[-–—:]+\s*/g, '');
  s = s.replace(/[_\-–—/\\|:.]/g, ' ');
  s = s.replace(/\s+/g, ' ').trim();
  return s;
};

const getAudioDuration = (file) => {
  return new Promise((resolve) => {
    try {
      const audio = new Audio();
      const objectUrl = URL.createObjectURL(file);
      audio.src = objectUrl;
      audio.onloadedmetadata = () => {
        const sec = Math.round(audio.duration);
        URL.revokeObjectURL(objectUrl);
        resolve(sec > 0 ? sec : 0);
      };
      audio.onerror = () => {
        URL.revokeObjectURL(objectUrl);
        resolve(0);
      };
    } catch (_) {
      resolve(0);
    }
  });
};

export default function IngestView({ onIngestSuccess }) {
  const [queue, setQueue] = useState([]);
  const [playingId, setPlayingId] = useState(null);
  const audioPreviewRef = useRef(null);

  const togglePlayPreview = (item) => {
    if (playingId === item.id) {
      if (audioPreviewRef.current) {
        audioPreviewRef.current.pause();
      }
      setPlayingId(null);
    } else {
      if (audioPreviewRef.current) {
        audioPreviewRef.current.pause();
      }
      const audio = new Audio(URL.createObjectURL(item.file));
      audio.onended = () => setPlayingId(null);
      audio.play().catch(() => {});
      audioPreviewRef.current = audio;
      setPlayingId(item.id);
    }
  };

  const handleFilesAdded = async (files) => {
    const fileList = Array.from(files);
    const existingNames = new Set(queue.map((q) => q.file.name));
    const uniqueFiles = fileList.filter((f) => !existingNames.has(f.name));

    if (uniqueFiles.length === 0) return;

    // 1. Instantly instantiate items in queue for 0ms lag
    const newItems = uniqueFiles.map((file) => {
      const itemId = Math.random().toString(36).substring(2, 9);
      const rawBaseName = file.name.replace(/\.[^/.]+$/, '');
      const initialTitle = ultraSanitize(rawBaseName) || rawBaseName;

      return {
        id: itemId,
        file,
        title: initialTitle,
        artistName: '',
        movieName: '',
        albumName: '',
        genre: '',
        language: 'Tamil',
        artworkUrl: '',
        duration: 0,
        status: 'idle',
        progress: 0,
        errorMsg: '',
        isAutoSearching: true,
        isAppleVerified: false,
        isSpotifyVerified: false,
        isSaavnVerified: false,
        isDualVerified: false,
        isEmbeddedVerified: false,
      };
    });

    setQueue((prev) => [...prev, ...newItems]);

    // 2. Asynchronously process each file concurrently (ID3 Tags + HTML5 Duration + Apple & Spotify Metadata)
    newItems.forEach(async (item) => {
      let extractedTitle = item.title;
      let extractedArtist = '';
      let extractedAlbum = '';
      let extractedArtwork = '';
      let extractedDuration = 0;

      // Extract Audio Duration from Native HTML5 Decoder
      try {
        extractedDuration = await getAudioDuration(item.file);
      } catch (_) {}

      // Extract Embedded ID3 Tags
      try {
        const parsed = await mm.parseBlob(item.file, { duration: true });
        const common = parsed.common || {};
        const format = parsed.format || {};

        if (common.title) {
          extractedTitle = ultraSanitize(common.title) || extractedTitle;
        }
        if (common.artist) {
          extractedArtist = ultraSanitize(common.artist);
        }
        if (common.album) {
          extractedAlbum = ultraSanitize(common.album);
        }
        if ((!extractedDuration || extractedDuration <= 0) && format.duration) {
          extractedDuration = Math.round(format.duration);
        }
        if (common.picture && common.picture.length > 0) {
          try {
            const pic = common.picture[0];
            const blob = new Blob([pic.data], { type: pic.format });
            extractedArtwork = URL.createObjectURL(blob);
          } catch (_) {}
        }
      } catch (e) {
        console.warn('Embedded tag parser notice:', e.message);
      }

      const finalArtist = extractedArtist.trim(); // No default — leave empty if not found in tags
      const finalMovie = extractedAlbum.trim();    // No default — leave empty if no album tag

      // Update item with embedded tags only (no defaults)
      setQueue((prev) =>
        prev.map((q) =>
          q.id === item.id
            ? {
                ...q,
                title: extractedTitle || q.title,
                artistName: finalArtist || q.artistName,
                movieName: finalMovie || q.movieName,
                albumName: finalMovie || q.albumName,
                artworkUrl: extractedArtwork || q.artworkUrl,
                duration: extractedDuration > 0 ? extractedDuration : q.duration,
                isEmbeddedVerified: !!extractedArtwork,
              }
            : q
        )
      );

      // Trigger Apple Music + Spotify + JioSaavn High-Precision Search
      autoFetchMetadata(item.id, extractedTitle, finalMovie, finalArtist, item.file.name);
    });
  };

  const updateItem = (id, field, value) => {
    setQueue((prev) => {
      const currentItem = prev.find((i) => i.id === id);
      const currentMovie = (currentItem?.movieName || currentItem?.albumName || '').toLowerCase().trim();

      return prev.map((item) => {
        if (item.id === id) {
          const updated = { ...item, [field]: value };
          if (field === 'artworkUrl') {
            updated.isAppleVerified = value && value.includes('mzstatic.com');
            updated.isSpotifyVerified = value && value.includes('spotifycdn.com');
            updated.isSaavnVerified = value && value.includes('saavncdn.com');
          }
          return updated;
        }

        // Automatic Movie Artwork Synchronization across Queue
        if (field === 'artworkUrl' && value && currentMovie && currentMovie !== 'single') {
          const itemMovie = (item.movieName || item.albumName || '').toLowerCase().trim();
          if (itemMovie === currentMovie) {
            return {
              ...item,
              artworkUrl: value,
              isAppleVerified: value.includes('mzstatic.com'),
              isSpotifyVerified: value.includes('spotifycdn.com'),
              isSaavnVerified: value.includes('saavncdn.com'),
            };
          }
        }

        return item;
      });
    });
  };

  const removeItem = (id) => {
    if (playingId === id && audioPreviewRef.current) {
      audioPreviewRef.current.pause();
      setPlayingId(null);
    }
    setQueue((prev) => prev.filter((item) => item.id !== id));
  };

  const autoFetchMetadata = async (id, title, album, artist, rawFilename) => {
    try {
      updateItem(id, 'isAutoSearching', true);
      const res = await api.searchAppleMetadata({
        title,
        album,
        artist,
        query: rawFilename,
        rawFilename,
      });

      if (res.success && res.metadata) {
        const resolvedMovie = res.metadata.movieName || res.metadata.album || '';
        const resolvedArtwork = res.metadata.artworkUrl;
        const resolvedArtist = res.metadata.artistName || res.metadata.artist || '';
        const resolvedTitle = res.metadata.title || '';
        const resolvedGenre = res.metadata.genre || '';

        setQueue((prev) => {
          const normMovie = (resolvedMovie || '').toLowerCase().trim();
          return prev.map((item) => {
            if (item.id === id) {
              return {
                ...item,
                // Only override if verified value is non-empty
                title: resolvedTitle || item.title,
                artistName: resolvedArtist || item.artistName,
                movieName: resolvedMovie || item.movieName,
                albumName: resolvedMovie || item.albumName,
                genre: resolvedGenre || item.genre,
                artworkUrl: resolvedArtwork || item.artworkUrl,
                duration: item.duration > 0 ? item.duration : (res.metadata.duration || 0),
                isAutoSearching: false,
                isAppleVerified:
                  !!res.metadata.isAppleMusicVerified ||
                  (!!resolvedArtwork && resolvedArtwork.includes('mzstatic.com')),
                isSpotifyVerified: !!res.metadata.isSpotifyVerified,
                isSaavnVerified: !!res.metadata.isSaavnVerified,
                isDualVerified: !!res.metadata.isDualVerified,
                isEmbeddedVerified: !resolvedArtwork && !!item.artworkUrl,
              };
            }

            // AUTO MOVIE-LEVEL ARTWORK SYNCHRONIZATION
            const itemMovie = (item.movieName || item.albumName || '').toLowerCase().trim();
            if (
              resolvedArtwork &&
              normMovie &&
              normMovie !== 'single' &&
              itemMovie === normMovie &&
              (!item.artworkUrl || item.artworkUrl.startsWith('blob:'))
            ) {
              return {
                ...item,
                artworkUrl: resolvedArtwork,
                movieName: resolvedMovie,
                albumName: resolvedMovie,
                isAppleVerified: resolvedArtwork.includes('mzstatic.com'),
                isSpotifyVerified: resolvedArtwork.includes('spotifycdn.com'),
                isSaavnVerified: resolvedArtwork.includes('saavncdn.com'),
              };
            }

            return item;
          });
        });
      } else {
        updateItem(id, 'isAutoSearching', false);
      }
    } catch (err) {
      console.warn('Metadata search error:', err);
      updateItem(id, 'isAutoSearching', false);
    }
  };

  const uploadItem = async (item) => {
    if (!item.title.trim()) {
      alert('Please ensure Song Title is filled.');
      return;
    }

    const cleanArtist = item.artistName.trim() || 'Soundtrack';

    updateItem(item.id, 'status', 'uploading');
    updateItem(item.id, 'progress', 0);

    try {
      // 1. Direct High-Speed Streaming Upload to Backend + Direct Embedded Tag Extraction
      const uploadResult = await new Promise((resolve, reject) => {
        const xhr = new XMLHttpRequest();
        const uploadUrl = `/api/v1/uploads/direct?fileName=${encodeURIComponent(item.file.name)}`;
        xhr.open('PUT', uploadUrl, true);
        xhr.setRequestHeader('Content-Type', item.file.type || 'audio/mpeg');

        xhr.upload.onprogress = (e) => {
          if (e.lengthComputable) {
            const pct = Math.round((e.loaded / e.total) * 100);
            updateItem(item.id, 'progress', pct);
          }
        };

        xhr.onload = () => {
          if (xhr.status === 200 || xhr.status === 201) {
            try {
              const gData = JSON.parse(xhr.responseText);
              resolve({
                fileId: gData.id || gData.fileId || ('vlt_' + Date.now()),
                embeddedMetadata: gData.embeddedMetadata,
              });
            } catch (_) {
              resolve({ fileId: 'vlt_' + Date.now(), embeddedMetadata: null });
            }
          } else {
            reject(new Error(`Upload failed with status ${xhr.status}`));
          }
        };

        xhr.onerror = () => reject(new Error('Network connection error during upload'));
        xhr.send(item.file);
      });

      const { fileId, embeddedMetadata } = uploadResult;
      const finalArt =
        item.artworkUrl && !item.artworkUrl.startsWith('blob:')
          ? item.artworkUrl
          : embeddedMetadata?.artworkUrl || item.artworkUrl || '';

      // 2. Save Track in Catalog with 100% Apple Music, Spotify, & Direct Embedded ID3 Tags
      const compRes = await api.completeUpload({
        fileId,
        title: item.title || embeddedMetadata?.title,
        artistName: cleanArtist || embeddedMetadata?.artist,
        movieName: item.movieName || embeddedMetadata?.album || item.title,
        albumName: item.albumName || embeddedMetadata?.album || item.movieName || item.title,
        genre: item.genre || embeddedMetadata?.genre,
        language: item.language,
        duration: item.duration > 0 ? item.duration : embeddedMetadata?.duration,
        artworkUrl: finalArt,
      });

      if (!compRes.success) {
        throw new Error(compRes.message || 'Failed to complete ingestion.');
      }

      updateItem(item.id, 'status', 'success');
      updateItem(item.id, 'progress', 100);

      if (onIngestSuccess) onIngestSuccess(compRes.song);
    } catch (err) {
      updateItem(item.id, 'status', 'error');
      updateItem(item.id, 'errorMsg', err.message);
    }
  };

  const uploadAll = async () => {
    const pendingItems = queue.filter((q) => q.status === 'idle' || q.status === 'error');
    for (const item of pendingItems) {
      await uploadItem(item);
    }
  };

  const clearQueue = () => {
    if (audioPreviewRef.current) {
      audioPreviewRef.current.pause();
      setPlayingId(null);
    }
    setQueue([]);
  };

  return (
    <div className="p-8 space-y-6 max-w-6xl mx-auto">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-slate-900 tracking-tight">Audio Ingest Pipeline</h1>
          <p className="text-xs text-slate-500 mt-0.5">
            Auto Metadata Extraction • Apple Music & Spotify Double Verification • 1400x1400 HD Artworks
          </p>
        </div>

        {queue.length > 0 && (
          <div className="flex items-center gap-2">
            <button
              onClick={clearQueue}
              className="px-3 py-1.5 rounded-lg border border-slate-200 hover:bg-slate-50 text-slate-600 text-xs font-medium transition shadow-xs"
            >
              Clear Queue
            </button>
            <button
              onClick={uploadAll}
              className="px-4 py-1.5 rounded-lg bg-slate-900 hover:bg-slate-800 text-white text-xs font-semibold transition shadow-xs flex items-center gap-1.5"
            >
              <UploadCloud className="w-3.5 h-3.5" />
              Upload All ({queue.filter((q) => q.status !== 'success').length})
            </button>
          </div>
        )}
      </div>

      {/* Drag & Drop Upload Box */}
      <label className="relative group border-2 border-dashed border-slate-200 hover:border-slate-400 bg-white hover:bg-slate-50/50 rounded-2xl p-8 flex flex-col items-center justify-center cursor-pointer transition text-center shadow-xs">
        <input
          type="file"
          multiple
          accept="audio/*"
          className="hidden"
          onChange={(e) => handleFilesAdded(e.target.files)}
        />
        <div className="w-12 h-12 rounded-2xl bg-slate-100 group-hover:bg-slate-200/80 flex items-center justify-center text-slate-600 group-hover:scale-105 transition duration-200 mb-3">
          <UploadCloud className="w-6 h-6 text-slate-700" />
        </div>
        <p className="text-sm font-semibold text-slate-900">Click or Drag & Drop audio files here</p>
        <p className="text-xs text-slate-400 mt-1">
          Supports MP3, FLAC, M4A, WAV • Instant Triple-Source Analysis (Apple Music, Spotify, Embedded Tags)
        </p>
      </label>

      {/* Upload Queue Table */}
      {queue.length > 0 && (
        <div className="rounded-2xl border border-slate-200 bg-white overflow-hidden shadow-xs">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-50/75 border-b border-slate-100 text-[11px] font-semibold text-slate-500 select-none">
              <tr>
                <th className="py-3 px-3 w-10 text-center">Play</th>
                <th className="py-3 px-3 w-12 text-center">Cover</th>
                <th className="py-3 px-4">Song Title</th>
                <th className="py-3 px-4">Artist</th>
                <th className="py-3 px-4">Album / Movie</th>
                <th className="py-3 px-4 w-20 text-center">Duration</th>
                <th className="py-3 px-4">Verification</th>
                <th className="py-3 px-4 text-right">Action</th>
              </tr>
            </thead>

            <tbody className="divide-y divide-slate-100 text-slate-700">
              {queue.map((item) => (
                <tr key={item.id} className="hover:bg-slate-50/80 transition group">
                  {/* Play Preview Button */}
                  <td className="py-3 px-3 text-center">
                    <button
                      onClick={() => togglePlayPreview(item)}
                      title="Preview Audio"
                      className="w-7 h-7 rounded-full bg-slate-100 hover:bg-slate-900 text-slate-600 hover:text-white flex items-center justify-center mx-auto transition"
                    >
                      {playingId === item.id ? <Pause className="w-3.5 h-3.5" /> : <Play className="w-3.5 h-3.5 ml-0.5" />}
                    </button>
                  </td>

                  {/* Artwork Preview */}
                  <td className="py-3 px-3 text-center">
                    <div className="w-10 h-10 rounded-lg bg-slate-100 overflow-hidden shrink-0 border border-slate-200 flex items-center justify-center mx-auto relative group/art">
                      {item.artworkUrl ? (
                        <img src={item.artworkUrl} alt="" className="w-full h-full object-cover" />
                      ) : (
                        <Music className="w-4 h-4 text-slate-400" />
                      )}
                    </div>
                  </td>

                  {/* Title Input */}
                  <td className="py-3 px-4">
                    <input
                      type="text"
                      value={item.title}
                      onChange={(e) => updateItem(item.id, 'title', e.target.value)}
                      placeholder="Song title..."
                      className="w-full bg-slate-50 hover:bg-slate-100/80 focus:bg-white border border-transparent focus:border-blue-400 rounded-md px-2 py-1 font-semibold text-slate-900 focus:outline-none text-xs transition"
                    />
                  </td>

                  {/* Artist Input — edits immediately saved to queue */}
                  <td className="py-3 px-4">
                    <input
                      type="text"
                      value={item.artistName}
                      onChange={(e) => updateItem(item.id, 'artistName', e.target.value)}
                      onBlur={(e) => {
                        // On blur: if artist changed, mark as manually edited
                        if (e.target.value !== item._editedArtist) {
                          updateItem(item.id, '_manuallyEdited', true);
                        }
                      }}
                      placeholder="Artist / Composer..."
                      className="w-full bg-slate-50 hover:bg-slate-100/80 focus:bg-white border border-transparent focus:border-blue-400 rounded-md px-2 py-1 text-slate-700 focus:outline-none text-xs font-medium transition"
                    />
                  </td>

                  {/* Album Input */}
                  <td className="py-3 px-4">
                    <input
                      type="text"
                      value={item.movieName}
                      onChange={(e) => {
                        updateItem(item.id, 'movieName', e.target.value);
                        updateItem(item.id, 'albumName', e.target.value);
                      }}
                      placeholder="Movie / Album..."
                      className="w-full bg-slate-50 hover:bg-slate-100/80 focus:bg-white border border-transparent focus:border-blue-400 rounded-md px-2 py-1 text-slate-600 focus:outline-none text-xs transition"
                    />
                  </td>

                  {/* Exact Duration (mm:ss) */}
                  <td className="py-3 px-4 text-center font-mono text-[11px] font-semibold text-slate-700">
                    {item.duration > 0 ? (
                      <span className="inline-flex items-center px-2 py-0.5 rounded bg-slate-100 text-slate-700">
                        {Math.floor(item.duration / 60)}:{(item.duration % 60).toString().padStart(2, '0')}
                      </span>
                    ) : (
                      <span className="text-slate-400">...</span>
                    )}
                  </td>

                  {/* Status & Verification */}
                  <td className="py-3 px-4">
                    <div className="flex items-center gap-1.5 flex-wrap">
                      {item.isAutoSearching ? (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-medium bg-amber-50 text-amber-600 animate-pulse">
                          <Sparkles className="w-3 h-3 animate-spin" /> Verifying...
                        </span>
                      ) : item.isDualVerified ? (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
                          <ShieldCheck className="w-3 h-3 text-emerald-600" /> Apple + Spotify
                        </span>
                      ) : item.isAppleVerified ? (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
                          <ShieldCheck className="w-3 h-3 text-emerald-600" /> 100% Apple HD
                        </span>
                      ) : item.isSpotifyVerified ? (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
                          <ShieldCheck className="w-3 h-3 text-emerald-600" /> Spotify Verified
                        </span>
                      ) : item.isSaavnVerified ? (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
                          <ShieldCheck className="w-3 h-3 text-emerald-600" /> Online HD Verified
                        </span>
                      ) : item.isEmbeddedVerified ? (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-semibold bg-indigo-50 text-indigo-700 border border-indigo-200">
                          <ShieldCheck className="w-3 h-3 text-indigo-600" /> Embedded Tag
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-medium bg-slate-100 text-slate-600">
                          Cleaned Meta
                        </span>
                      )}

                      {/* Manual Re-fetch Button */}
                      <button
                        onClick={() =>
                          autoFetchMetadata(item.id, item.title, item.movieName, item.artistName, item.file.name)
                        }
                        title="Re-fetch Apple Music & Spotify Meta"
                        className="p-1 rounded text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition opacity-0 group-hover:opacity-100"
                      >
                        <RefreshCw className="w-3 h-3" />
                      </button>
                    </div>
                  </td>

                  {/* Action */}
                  <td className="py-3 px-4 text-right">
                    <div className="flex items-center justify-end gap-1.5">
                      {item.status === 'uploading' ? (
                        <div className="flex items-center justify-end gap-2 text-[11px] font-medium text-slate-600">
                          <div className="w-16 bg-slate-200 rounded-full h-1.5 overflow-hidden">
                            <div
                              className="bg-slate-900 h-full transition-all duration-150"
                              style={{ width: `${item.progress}%` }}
                            />
                          </div>
                          <span>{item.progress}%</span>
                        </div>
                      ) : item.status === 'success' ? (
                        <span className="inline-flex items-center gap-1 text-emerald-600 font-semibold text-xs">
                          <CheckCircle2 className="w-4 h-4" /> Saved
                        </span>
                      ) : item.status === 'error' ? (
                        <button
                          onClick={() => uploadItem(item)}
                          className="px-2.5 py-1 rounded bg-rose-50 hover:bg-rose-100 text-rose-600 text-[11px] font-medium transition"
                        >
                          Retry
                        </button>
                      ) : (
                        // Save button — always uses the LATEST live queue state (artist, title, movie all included)
                        <button
                          onClick={() => {
                            // Re-read latest item state from queue at click time
                            setQueue((prev) => {
                              const latest = prev.find((q) => q.id === item.id);
                              if (latest) uploadItem(latest);
                              return prev;
                            });
                          }}
                          disabled={!item.title?.trim()}
                          className="px-3 py-1 rounded-lg bg-slate-900 hover:bg-slate-800 disabled:opacity-40 disabled:cursor-not-allowed text-white font-medium text-[11px] transition shadow-xs"
                        >
                          Save
                        </button>
                      )}

                      {/* Dismiss / Delete Item from Queue */}
                      {item.status !== 'uploading' && (
                        <button
                          onClick={() => removeItem(item.id)}
                          title="Remove from queue"
                          className="p-1 rounded text-slate-400 hover:text-rose-600 hover:bg-rose-50 transition"
                        >
                          <X className="w-3.5 h-3.5" />
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
