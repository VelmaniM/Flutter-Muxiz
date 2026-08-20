'use client';

import React, { useState } from 'react';
import { X, Save, Upload } from 'lucide-react';

export default function EditSongModal({ song, onClose, onSave, showToast }) {
  const [title, setTitle] = useState(song.title || '');
  const [artistName, setArtistName] = useState(song.artistName || '');
  const [movieName, setMovieName] = useState(song.movieName || song.albumName || '');
  const [genre, setGenre] = useState(song.genre || '');
  const [artworkUrl, setArtworkUrl] = useState(song.artworkUrl || '');
  const [isSaving, setIsSaving] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsSaving(true);

    try {
      const res = await fetch(`/api/songs/${song.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          title,
          artistName,
          movieName,
          albumName: movieName,
          genre,
          artworkUrl,
        }),
      });

      const json = await res.json();
      if (json.success) {
        showToast('Song updated successfully!');
        if (onSave) onSave();
        onClose();
      } else {
        showToast(`Failed: ${json.message}`);
      }
    } catch (err) {
      showToast(`Error: ${err.message}`);
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(0, 0, 0, 0.4)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 1000,
      }}
      onClick={onClose}
    >
      <div
        style={{
          background: '#FFFFFF',
          borderRadius: '8px',
          width: '480px',
          maxWidth: '90vw',
          padding: '24px',
          boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1)',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
          <h3 style={{ fontSize: '15px', fontWeight: 700, color: 'var(--text-main)' }}>
            Edit Track Metadata
          </h3>
          <button onClick={onClose} className="play-icon-btn">
            <X size={16} />
          </button>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          <div>
            <label className="input-minimal-label">Track Title</label>
            <input
              type="text"
              className="input-minimal-ctrl"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              required
            />
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
            <div>
              <label className="input-minimal-label">Movie / Album</label>
              <input
                type="text"
                className="input-minimal-ctrl"
                value={movieName}
                onChange={(e) => setMovieName(e.target.value)}
              />
            </div>

            <div>
              <label className="input-minimal-label">Artist(s)</label>
              <input
                type="text"
                className="input-minimal-ctrl"
                value={artistName}
                onChange={(e) => setArtistName(e.target.value)}
              />
            </div>
          </div>

          <div>
            <label className="input-minimal-label">Genre & Mood</label>
            <input
              type="text"
              className="input-minimal-ctrl"
              value={genre}
              onChange={(e) => setGenre(e.target.value)}
              list="genreMoodOptions"
            />
          </div>

          <div>
            <label className="input-minimal-label">Artwork URL</label>
            <input
              type="text"
              className="input-minimal-ctrl"
              value={artworkUrl}
              onChange={(e) => setArtworkUrl(e.target.value)}
              placeholder="https://..."
            />
          </div>

          {/* Footer Buttons */}
          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px', marginTop: '12px' }}>
            <button type="button" onClick={onClose} className="btn-minimal-light">
              Cancel
            </button>
            <button type="submit" className="btn-minimal-dark" disabled={isSaving}>
              <Save size={14} />
              <span>{isSaving ? 'Saving...' : 'Save Changes'}</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
