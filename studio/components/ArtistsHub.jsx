'use client';

import React, { useState, useRef } from 'react';
import { Users, Upload, Play, Music, Camera, Plus } from 'lucide-react';

export default function ArtistsHub({ artists, onPlaySong, showToast, onRefresh, onOpenAddSong }) {
  const [selectedArtist, setSelectedArtist] = useState(null);
  const [isUploadingPhoto, setIsUploadingPhoto] = useState(false);
  const photoInputRef = useRef(null);

  const handleUploadPhoto = async (artist, file) => {
    if (!file) return;
    setIsUploadingPhoto(true);

    try {
      const formData = new FormData();
      formData.append('file', file);

      const uploadRes = await fetch('/api/uploads/artist-photo', {
        method: 'POST',
        body: formData,
      });
      const uploadJson = await uploadRes.json();

      if (uploadJson.success && uploadJson.imageUrl) {
        // Update artist in DB
        await fetch(`/api/artists/${artist.id}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ imageUrl: uploadJson.imageUrl }),
        });

        showToast(`Updated portrait for ${artist.name}!`);
        if (onRefresh) onRefresh();
      } else {
        showToast(`Failed to upload photo: ${uploadJson.message}`);
      }
    } catch (err) {
      showToast(`Error: ${err.message}`);
    } finally {
      setIsUploadingPhoto(false);
    }
  };

  return (
    <div>
      <input
        type="file"
        ref={photoInputRef}
        accept="image/*"
        style={{ display: 'none' }}
        onChange={(e) => {
          if (e.target.files && selectedArtist) {
            handleUploadPhoto(selectedArtist, e.target.files[0]);
          }
        }}
      />

      {/* Top Header */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          marginBottom: '20px',
          flexWrap: 'wrap',
          gap: '12px',
        }}
      >
        <div>
          <h2 className="page-title" style={{ margin: 0 }}>Artists & Discographies</h2>
          <p className="page-subtitle" style={{ margin: '4px 0 0' }}>
            Manage music composers, singers, portraits, and their catalog track relations.
          </p>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          {/* Artists Count Badge */}
          <div
            style={{
              fontSize: '12px',
              fontWeight: 700,
              color: 'var(--text-main)',
              background: 'var(--bg-subtle)',
              border: '1px solid var(--border-main)',
              padding: '6px 12px',
              borderRadius: '20px',
              display: 'inline-flex',
              alignItems: 'center',
              gap: '5px',
            }}
          >
            <span>👥</span>
            <span>{artists.length} Artists</span>
          </div>

          {/* Add Song Button */}
          <button
            onClick={onOpenAddSong}
            className="btn-minimal-dark"
            style={{
              padding: '6px 14px',
              borderRadius: '8px',
              fontSize: '12.5px',
              fontWeight: 700,
              display: 'inline-flex',
              alignItems: 'center',
              gap: '6px',
              background: '#0F172A',
              color: '#FFFFFF',
              border: 'none',
              cursor: 'pointer',
              boxShadow: '0 1px 3px rgba(0,0,0,0.1)',
            }}
            title="Add New Song / Upload Audio"
          >
            <Plus size={14} />
            <span>Add Song</span>
          </button>
        </div>
      </div>

      {/* Artists Grid */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))',
          gap: '16px',
        }}
      >
        {artists.map((artist) => {
          const trackCount = artist.songs?.length || artist.songCount || 0;

          return (
            <div
              key={artist.id || artist.name}
              style={{
                background: '#FFFFFF',
                border: '1px solid var(--border-main)',
                borderRadius: '12px',
                padding: '20px 16px 16px',
                textAlign: 'center',
                boxShadow: '0 1px 3px rgba(0,0,0,0.02)',
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'space-between',
                alignItems: 'center',
                minHeight: '275px',
                transition: 'all 0.2s ease',
              }}
            >
              {/* Upper Body: Portrait, Name & Track Count */}
              <div style={{ width: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                <div style={{ position: 'relative', width: '80px', height: '80px', marginBottom: '12px' }}>
                  <img
                    src={artist.image || artist.imageUrl || artist.artwork || '/app_logo.png'}
                    alt={artist.name}
                    style={{
                      width: '100%',
                      height: '100%',
                      borderRadius: '50%',
                      objectFit: 'cover',
                      border: '2px solid #F1F5F9',
                      boxShadow: '0 4px 10px rgba(0,0,0,0.06)',
                    }}
                    onError={(e) => {
                      e.target.src = '/app_logo.png';
                    }}
                  />
                  <button
                    onClick={() => {
                      setSelectedArtist(artist);
                      photoInputRef.current?.click();
                    }}
                    className="play-icon-btn"
                    title="Upload Custom Photo"
                    style={{
                      position: 'absolute',
                      bottom: 0,
                      right: 0,
                      background: '#0F172A',
                      color: '#FFFFFF',
                      padding: '5px',
                      borderRadius: '50%',
                      boxShadow: '0 2px 6px rgba(0,0,0,0.2)',
                    }}
                  >
                    <Camera size={12} />
                  </button>
                </div>

                {/* Name */}
                <h3
                  style={{
                    fontSize: '14.5px',
                    fontWeight: 700,
                    color: 'var(--text-main)',
                    marginBottom: '4px',
                    lineHeight: 1.3,
                    maxWidth: '100%',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    whiteSpace: 'nowrap',
                  }}
                  title={artist.name}
                >
                  {artist.name}
                </h3>

                {/* Track Badge */}
                <span
                  style={{
                    fontSize: '11px',
                    fontWeight: 600,
                    color: '#475569',
                    background: '#F8FAFC',
                    border: '1px solid #E2E8F0',
                    padding: '2px 10px',
                    borderRadius: '16px',
                    marginBottom: '12px',
                  }}
                >
                  🎵 {trackCount} {trackCount === 1 ? 'Track' : 'Tracks'}
                </span>
              </div>

              {/* Bottom Action Section: Always pinned at the bottom for all cards */}
              <div
                style={{
                  width: '100%',
                  marginTop: 'auto',
                  paddingTop: '12px',
                  borderTop: '1px solid #F1F5F9',
                }}
              >
                {trackCount > 0 ? (
                  <button
                    onClick={() => onPlaySong(artist.songs[0])}
                    style={{
                      width: '100%',
                      padding: '8px 12px',
                      borderRadius: '8px',
                      fontSize: '12px',
                      fontWeight: 700,
                      background: '#10B981',
                      color: '#FFFFFF',
                      border: '1px solid #059669',
                      cursor: 'pointer',
                      display: 'inline-flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      gap: '6px',
                      boxShadow: '0 1px 3px rgba(16, 185, 129, 0.2)',
                      transition: 'all 0.15s ease',
                    }}
                    title={`Play ${artist.name}`}
                  >
                    <Play size={13} fill="#FFFFFF" />
                    <span>Play Top Track</span>
                  </button>
                ) : (
                  <span style={{ fontSize: '11.5px', color: 'var(--text-dim)' }}>No audio available</span>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
