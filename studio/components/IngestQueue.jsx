'use client';

import React, { useState, useRef } from 'react';
import {
  UploadCloud,
  Play,
  Pause,
  Trash2,
  CheckCircle2,
  AlertCircle,
  FileAudio,
  Search,
  Sparkles,
  Image as ImageIcon,
  Camera,
} from 'lucide-react';
import {
  parseFilenameMetadata,
  detectGenreAndMood,
  cleanTrackTitle,
  cleanMovieOrAlbumName,
  cleanRawString,
  fetchAppleMusicMetadata,
} from '@/lib/metadata';

export default function IngestQueue({ onUploadSuccess, showToast }) {
  const [queue, setQueue] = useState([]);
  const [isDragging, setIsDragging] = useState(false);
  const [isBatchUploading, setIsBatchUploading] = useState(false);
  const [previewingId, setPreviewingId] = useState(null);
  const fileInputRef = useRef(null);
  const audioPreviewRef = useRef(null);

  // Handle files selected from file dialog or drag-and-drop
  const handleFiles = async (fileList) => {
    const validFiles = Array.from(fileList).filter((f) =>
      /\.(mp3|m4a|wav|flac|aac|ogg|opus)$/i.test(f.name)
    );

    if (validFiles.length === 0) {
      showToast('Please select valid audio files (.mp3, .m4a, .wav, .flac).');
      return;
    }

    const newItems = validFiles.map((file) => {
      const parsed = parseFilenameMetadata(file.name);
      const genreMood = detectGenreAndMood(parsed.title, parsed.movieName, parsed.artist, '');
      const blobUrl = URL.createObjectURL(file);

      return {
        id: `queue_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        file,
        title: parsed.title,
        movieName: parsed.movieName,
        albumName: parsed.album || parsed.movieName,
        artistName: parsed.artist,
        genre: genreMood,
        language: 'Tamil',
        artworkUrl: '',
        blobUrl,
        isSearchingArt: true,
        uploadStatus: 'idle', // 'idle' | 'uploading' | 'success' | 'error'
        uploadProgress: 0,
        errorMessage: '',
      };
    });

    setQueue((prev) => [...prev, ...newItems]);
    showToast(`Added ${newItems.length} track(s) to queue. Auto-fetching artwork...`);

    // Concurrently query Apple Music for Official HD Artwork & accurate metadata
    newItems.forEach(async (item) => {
      try {
        const appleData = await fetchAppleMusicMetadata(item.title, item.movieName, item.artistName);

        if (appleData) {
          setQueue((curr) =>
            curr.map((q) =>
              q.id === item.id
                ? {
                    ...q,
                    artworkUrl: appleData.artworkUrl || q.artworkUrl,
                    title: appleData.title || q.title,
                    movieName: appleData.movieName || q.movieName,
                    albumName: appleData.movieName || q.movieName,
                    artistName: appleData.artistName !== 'Unknown Artist' ? appleData.artistName : q.artistName,
                    genre: appleData.genre || q.genre,
                    isSearchingArt: false,
                  }
                : q
            )
          );
        } else {
          setQueue((curr) =>
            curr.map((q) => (q.id === item.id ? { ...q, isSearchingArt: false } : q))
          );
        }
      } catch (_) {
        setQueue((curr) =>
          curr.map((q) => (q.id === item.id ? { ...q, isSearchingArt: false } : q))
        );
      }
    });
  };

  const updateQueueItem = (id, field, value) => {
    setQueue((curr) =>
      curr.map((q) => (q.id === id ? { ...q, [field]: value } : q))
    );
  };

  const removeQueueItem = (id) => {
    setQueue((curr) => curr.filter((q) => q.id !== id));
    if (previewingId === id && audioPreviewRef.current) {
      audioPreviewRef.current.pause();
      setPreviewingId(null);
    }
  };

  const togglePreview = (item) => {
    if (!audioPreviewRef.current) return;

    if (previewingId === item.id) {
      audioPreviewRef.current.pause();
      setPreviewingId(null);
    } else {
      audioPreviewRef.current.src = item.blobUrl;
      audioPreviewRef.current.play();
      setPreviewingId(item.id);
    }
  };

  // Handle custom artwork file selection for a specific queue item
  const handleCustomArtwork = async (itemId, file) => {
    if (!file) return;
    try {
      showToast('Uploading custom artwork...');
      const formData = new FormData();
      formData.append('file', file);
      const res = await fetch('/api/uploads/artwork', {
        method: 'POST',
        body: formData,
      });
      const data = await res.json();
      if (data.success && data.artworkUrl) {
        updateQueueItem(itemId, 'artworkUrl', data.artworkUrl);
        showToast('Artwork updated successfully!');
      } else {
        const reader = new FileReader();
        reader.onload = (e) => {
          updateQueueItem(itemId, 'artworkUrl', e.target.result);
          showToast('Custom artwork selected!');
        };
        reader.readAsDataURL(file);
      }
    } catch (_) {
      const reader = new FileReader();
      reader.onload = (e) => {
        updateQueueItem(itemId, 'artworkUrl', e.target.result);
        showToast('Custom artwork selected!');
      };
      reader.readAsDataURL(file);
    }
  };

  // Upload single track with direct Google Drive Resumable Stream (bypasses Vercel 4.5MB limit)
  const uploadSingle = async (item) => {
    updateQueueItem(item.id, 'uploadStatus', 'uploading');
    updateQueueItem(item.id, 'uploadProgress', 0);

    try {
      // 1. Try Direct Google Drive Resumable Session
      let uploadSuccess = false;
      try {
        const sessionRes = await fetch('/api/uploads/session', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            fileName: item.title ? `${item.title}.mp3` : item.file.name,
            mimeType: item.file.type || 'audio/mpeg',
          }),
        });

        if (sessionRes.ok) {
          const sessionJson = await sessionRes.json();
          if (sessionJson.success && sessionJson.uploadUrl) {
            // Upload directly to Google Drive via XMLHttpRequest for smooth progress
            const fileId = await new Promise((resolve, reject) => {
              const xhr = new XMLHttpRequest();
              xhr.open('PUT', sessionJson.uploadUrl, true);
              xhr.setRequestHeader('Content-Type', item.file.type || 'audio/mpeg');

              xhr.upload.onprogress = (e) => {
                if (e.lengthComputable) {
                  const pct = Math.round((e.loaded / e.total) * 100);
                  updateQueueItem(item.id, 'uploadProgress', pct);
                }
              };

              xhr.onload = () => {
                if (xhr.status === 200 || xhr.status === 201) {
                  try {
                    const gData = JSON.parse(xhr.responseText);
                    resolve(gData.id);
                  } catch (err) {
                    reject(new Error('Invalid Google Drive response'));
                  }
                } else {
                  reject(new Error(`Google upload failed (${xhr.status})`));
                }
              };

              xhr.onerror = () => reject(new Error('Network error uploading to Google Drive'));
              xhr.send(item.file);
            });

            // Finalize metadata and save to PostgreSQL Database
            const completeRes = await fetch('/api/uploads/complete', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                fileId,
                title: item.title || item.file.name,
                artistName: item.artistName || 'Unknown Artist',
                movieName: item.movieName || item.albumName || 'Single',
                albumName: item.albumName || item.movieName || 'Single',
                genre: item.genre || 'Tamil · Melody / Romantic',
                language: item.language || 'Tamil',
                artworkUrl: item.artworkUrl || '',
              }),
            });

            const completeJson = await completeRes.json();
            if (completeJson.success) {
              uploadSuccess = true;
              updateQueueItem(item.id, 'uploadStatus', 'success');
              updateQueueItem(item.id, 'uploadProgress', 100);
              showToast(`"${item.title}" ingested & saved to Google Drive!`);
              if (onUploadSuccess) onUploadSuccess();
              setTimeout(() => removeQueueItem(item.id), 1200);
              return;
            } else {
              throw new Error(completeJson.message || 'Failed to save song in database');
            }
          }
        }
      } catch (directErr) {
        console.warn('[Direct Upload Fallback]', directErr.message);
      }

      if (uploadSuccess) return;

      // 2. Fallback to standard Multipart Ingestion route
      const formData = new FormData();
      formData.append('file', item.file);
      formData.append('title', item.title || item.file.name);
      formData.append('artistName', item.artistName || 'Unknown Artist');
      formData.append('movieName', item.movieName || item.albumName || 'Single');
      formData.append('albumName', item.albumName || item.movieName || 'Single');
      formData.append('genre', item.genre || 'Tamil · Melody / Romantic');
      formData.append('language', item.language || 'Tamil');
      if (item.artworkUrl) {
        formData.append('artworkUrl', item.artworkUrl);
      }

      const res = await fetch('/api/uploads/song', {
        method: 'POST',
        body: formData,
      });

      const text = await res.text();
      let json;
      try {
        json = JSON.parse(text);
      } catch (parseErr) {
        throw new Error(text.length < 120 ? text : 'Server returned an invalid response (payload too large).');
      }

      if (json.success) {
        updateQueueItem(item.id, 'uploadStatus', 'success');
        updateQueueItem(item.id, 'uploadProgress', 100);
        showToast(`Uploaded "${item.title}" successfully!`);
        if (onUploadSuccess) onUploadSuccess();
        setTimeout(() => removeQueueItem(item.id), 1200);
      } else {
        updateQueueItem(item.id, 'uploadStatus', 'error');
        updateQueueItem(item.id, 'errorMessage', json.message || 'Upload failed');
        showToast(`Error uploading "${item.title}": ${json.message}`);
      }
    } catch (err) {
      updateQueueItem(item.id, 'uploadStatus', 'error');
      updateQueueItem(item.id, 'errorMessage', err.message);
      showToast(`Upload error: ${err.message}`);
    }
  };

  // Batch upload all queued items
  const uploadAll = async () => {
    if (queue.length === 0 || isBatchUploading) return;
    setIsBatchUploading(true);

    for (const item of queue) {
      if (item.uploadStatus !== 'success') {
        await uploadSingle(item);
      }
    }

    setIsBatchUploading(false);
    showToast('Batch upload complete!');
    if (onUploadSuccess) onUploadSuccess();
  };

  return (
    <div>
      <audio ref={audioPreviewRef} onEnded={() => setPreviewingId(null)} />

      {/* Header & Controls */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          marginBottom: '20px',
        }}
      >
        <div>
          <h2 className="page-title">Ingest Queue</h2>
          <p className="page-subtitle">
            Upload audio files to Google Drive with automatic Apple Music artwork & metadata sync.
          </p>
        </div>

        {queue.length > 0 && (
          <div style={{ display: 'flex', gap: '8px' }}>
            <button
              onClick={() => setQueue([])}
              className="btn-minimal-light"
              disabled={isBatchUploading}
            >
              Clear Queue
            </button>
            <button
              onClick={uploadAll}
              className="btn-minimal-dark"
              disabled={isBatchUploading}
            >
              <UploadCloud size={15} />
              <span>{isBatchUploading ? 'Uploading All...' : `Upload All (${queue.length})`}</span>
            </button>
          </div>
        )}
      </div>

      {/* Drag and Drop Zone */}
      <div
        className={`minimal-dropzone ${isDragging ? 'dragover' : ''}`}
        onDragOver={(e) => {
          e.preventDefault();
          setIsDragging(true);
        }}
        onDragLeave={() => setIsDragging(false)}
        onDrop={(e) => {
          e.preventDefault();
          setIsDragging(false);
          if (e.dataTransfer.files) {
            handleFiles(e.dataTransfer.files);
          }
        }}
        onClick={() => fileInputRef.current?.click()}
        style={{ marginBottom: '24px' }}
      >
        <input
          type="file"
          ref={fileInputRef}
          multiple
          accept="audio/*,.mp3,.m4a,.wav,.flac,.aac,.ogg,.opus"
          style={{ display: 'none' }}
          onChange={(e) => {
            if (e.target.files) handleFiles(e.target.files);
          }}
        />

        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '8px' }}>
          <div
            style={{
              width: '44px',
              height: '44px',
              borderRadius: '50%',
              background: 'var(--bg-subtle)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#374151',
            }}
          >
            <FileAudio size={22} />
          </div>
          <div>
            <p style={{ fontSize: '13.5px', fontWeight: 600, color: 'var(--text-main)' }}>
              Click to select or drag and drop audio files
            </p>
            <p style={{ fontSize: '11.5px', color: 'var(--text-muted)', marginTop: '2px' }}>
              Supports MP3, M4A, WAV, FLAC with auto Apple Music HD artwork extraction
            </p>
          </div>
        </div>
      </div>

      {/* Queue Items List */}
      {queue.length === 0 ? (
        <div
          style={{
            padding: '40px',
            textAlign: 'center',
            background: '#FFFFFF',
            border: '1px solid var(--border-main)',
            borderRadius: '8px',
          }}
        >
          <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
            No tracks in the queue. Drag and drop audio files above to start ingesting!
          </p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          {queue.map((item) => {
            const isPlaying = previewingId === item.id;

            return (
              <div key={item.id} className="queue-row-card">
                <div style={{ display: 'flex', gap: '14px', alignItems: 'center' }}>
                  {/* 1. SEPARATE PLAY/PAUSE PREVIEW BUTTON ON LEFT */}
                  <button
                    onClick={() => togglePreview(item)}
                    style={{
                      width: '38px',
                      height: '38px',
                      borderRadius: '50%',
                      background: isPlaying ? 'var(--emerald)' : '#F3F4F6',
                      border: '1px solid var(--border-main)',
                      color: isPlaying ? '#FFFFFF' : '#374151',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      cursor: 'pointer',
                      flexShrink: 0,
                      transition: 'all 0.15s ease',
                    }}
                    title={isPlaying ? 'Pause Audio Preview' : 'Play Audio Preview'}
                  >
                    {isPlaying ? <Pause size={17} /> : <Play size={17} style={{ marginLeft: '2px' }} />}
                  </button>

                  {/* 2. ARTWORK THUMBNAIL (CLICK TO CHANGE ARTWORK) */}
                  <div
                    style={{ position: 'relative', width: '68px', height: '68px', flexShrink: 0, cursor: 'pointer' }}
                    title="Click to change / upload artwork"
                  >
                    <input
                      type="file"
                      id={`art_input_${item.id}`}
                      accept="image/*"
                      style={{ display: 'none' }}
                      onChange={(e) => {
                        if (e.target.files && e.target.files[0]) {
                          handleCustomArtwork(item.id, e.target.files[0]);
                        }
                      }}
                    />
                    <div
                      onClick={() => document.getElementById(`art_input_${item.id}`)?.click()}
                      style={{
                        width: '100%',
                        height: '100%',
                        borderRadius: '6px',
                        overflow: 'hidden',
                        position: 'relative',
                        background: '#F9FAFB',
                        border: '1px solid var(--border-main)',
                      }}
                    >
                      {item.artworkUrl ? (
                        <img
                          src={item.artworkUrl}
                          alt="Artwork"
                          style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                        />
                      ) : (
                        <div
                          style={{
                            width: '100%',
                            height: '100%',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                          }}
                        >
                          {item.isSearchingArt ? (
                            <Sparkles size={18} color="var(--emerald)" className="animate-spin" />
                          ) : (
                            <ImageIcon size={22} color="#9CA3AF" />
                          )}
                        </div>
                      )}

                      {/* Hover overlay to change artwork */}
                      <div
                        style={{
                          position: 'absolute',
                          inset: 0,
                          background: 'rgba(0,0,0,0.5)',
                          opacity: 0,
                          display: 'flex',
                          flexDirection: 'column',
                          alignItems: 'center',
                          justifyContent: 'center',
                          gap: '2px',
                          color: '#FFFFFF',
                          transition: 'opacity 0.2s',
                        }}
                        onMouseEnter={(e) => (e.currentTarget.style.opacity = '1')}
                        onMouseLeave={(e) => (e.currentTarget.style.opacity = '0')}
                      >
                        <Camera size={15} />
                        <span style={{ fontSize: '9px', fontWeight: 600 }}>Change</span>
                      </div>
                    </div>
                  </div>

                  {/* 3. METADATA INPUTS GRID */}
                  <div className="queue-grid-inputs" style={{ flex: 1 }}>
                    <div>
                      <label className="input-minimal-label">Track Title</label>
                      <input
                        type="text"
                        className="input-minimal-ctrl"
                        value={item.title}
                        onChange={(e) => updateQueueItem(item.id, 'title', e.target.value)}
                        placeholder="Song Title"
                      />
                    </div>

                    <div>
                      <label className="input-minimal-label">Movie / Album</label>
                      <input
                        type="text"
                        className="input-minimal-ctrl"
                        value={item.movieName}
                        onChange={(e) => {
                          updateQueueItem(item.id, 'movieName', e.target.value);
                          updateQueueItem(item.id, 'albumName', e.target.value);
                        }}
                        placeholder="Movie / Album"
                      />
                    </div>

                    <div>
                      <label className="input-minimal-label">Artist(s)</label>
                      <input
                        type="text"
                        className="input-minimal-ctrl"
                        value={item.artistName}
                        onChange={(e) => updateQueueItem(item.id, 'artistName', e.target.value)}
                        placeholder="Artist Name"
                      />
                    </div>

                    <div>
                      <label className="input-minimal-label">Genre & Mood</label>
                      <input
                        type="text"
                        className="input-minimal-ctrl"
                        value={item.genre}
                        onChange={(e) => updateQueueItem(item.id, 'genre', e.target.value)}
                        placeholder="Genre & Mood"
                        list="genreMoodOptions"
                      />
                    </div>

                    <div>
                      <label className="input-minimal-label">Cover Image URL</label>
                      <input
                        type="text"
                        className="input-minimal-ctrl"
                        value={item.artworkUrl || ''}
                        onChange={(e) => updateQueueItem(item.id, 'artworkUrl', e.target.value)}
                        placeholder="https://... (or click cover)"
                      />
                    </div>
                  </div>

                  {/* 4. ACTIONS & STATUS: UPLOAD AND DELETE SIDE-BY-SIDE */}
                  <div
                    style={{
                      display: 'flex',
                      flexDirection: 'row',
                      gap: '8px',
                      alignItems: 'center',
                      flexShrink: 0,
                    }}
                  >
                    {item.uploadStatus === 'idle' && (
                      <button
                        onClick={() => uploadSingle(item)}
                        className="btn-minimal-dark"
                        style={{
                          padding: '7px 14px',
                          fontSize: '12px',
                          display: 'flex',
                          alignItems: 'center',
                          gap: '6px',
                        }}
                      >
                        <UploadCloud size={14} />
                        <span>Upload</span>
                      </button>
                    )}

                    {item.uploadStatus === 'uploading' && (
                      <span style={{ fontSize: '11.5px', fontWeight: 600, color: 'var(--blue)' }}>
                        Uploading...
                      </span>
                    )}

                    {item.uploadStatus === 'success' && (
                      <span
                        style={{
                          fontSize: '11.5px',
                          fontWeight: 600,
                          color: 'var(--emerald)',
                          display: 'flex',
                          alignItems: 'center',
                          gap: '4px',
                        }}
                      >
                        <CheckCircle2 size={14} /> Saved
                      </span>
                    )}

                    {item.uploadStatus === 'error' && (
                      <span
                        style={{
                          fontSize: '11.5px',
                          fontWeight: 600,
                          color: 'var(--red)',
                          display: 'flex',
                          alignItems: 'center',
                          gap: '4px',
                        }}
                      >
                        <AlertCircle size={14} /> Failed
                      </span>
                    )}

                    <button
                      onClick={() => removeQueueItem(item.id)}
                      className="play-icon-btn"
                      title="Remove from queue"
                      style={{
                        width: '32px',
                        height: '32px',
                        borderRadius: '6px',
                        border: '1px solid var(--border-main)',
                        color: '#EF4444',
                        background: '#FFFFFF',
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                      }}
                    >
                      <Trash2 size={15} />
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Genre & Mood Datalist */}
      <datalist id="genreMoodOptions">
        <option value="Tamil · Melody / Romantic" />
        <option value="Tamil · Dance / Kuthu" />
        <option value="Tamil · Mass / Energetic" />
        <option value="Tamil · Soulful / Sad" />
        <option value="Tamil · Chill / Lo-Fi" />
        <option value="Tamil · Folk / Gaana" />
        <option value="Tamil · Hip-Hop / Rap" />
        <option value="Tamil · Classical / Devotional" />
      </datalist>
    </div>
  );
}
