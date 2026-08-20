'use client';

import React from 'react';
import { Search, Play, Pause, Edit3, Trash2, Plus, Power, RefreshCw } from 'lucide-react';

export default function CatalogTable({
  songs,
  onPlaySong,
  currentSong,
  isPlaying,
  onEditSong,
  onDeleteSong,
  onSearchChange,
  searchQuery,
  selectedGenre,
  onGenreChange,
  serverActive,
  onToggleServerPower,
  onOpenAddSong,
  onRefresh,
  isRefreshing,
}) {
  const genres = [
    'All',
    'Melody / Romantic',
    'Dance / Kuthu',
    'Mass / Energetic',
    'Soulful / Sad',
    'Chill / Lo-Fi',
    'Folk / Gaana',
    'Hip-Hop / Rap',
    'Classical / Devotional',
  ];

  const formatDuration = (seconds) => {
    if (!seconds) return '3:00';
    const m = Math.floor(seconds / 60);
    const s = Math.floor(seconds % 60);
    return `${m}:${s < 10 ? '0' + s : s}`;
  };

  return (
    <div>
      {/* Top Header Section with Count, Power Switch and Add Song Button */}
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
          <h2 className="page-title" style={{ margin: 0 }}>Music Catalog</h2>
          <p className="page-subtitle" style={{ margin: '4px 0 0' }}>
            Direct PostgreSQL database tracks live-streaming to the Muxiz mobile app.
          </p>
        </div>

        {/* Top Header Controls: Server Switch, Count Pill, Add Button */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap' }}>
          {/* Server Power Switch */}
          <button
            onClick={onToggleServerPower}
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '6px',
              padding: '6px 12px',
              borderRadius: '8px',
              fontSize: '12px',
              fontWeight: 700,
              cursor: 'pointer',
              border: serverActive ? '1px solid #10B981' : '1px solid #EF4444',
              background: serverActive ? '#ECFDF5' : '#FEF2F2',
              color: serverActive ? '#047857' : '#B91C1C',
              transition: 'all 0.15s ease',
            }}
            title="Toggle Studio Server ON/OFF"
          >
            <span
              style={{
                width: '7px',
                height: '7px',
                borderRadius: '50%',
                background: serverActive ? '#10B981' : '#EF4444',
                boxShadow: serverActive ? '0 0 0 2px rgba(16, 185, 129, 0.3)' : 'none',
              }}
            />
            <span>{serverActive ? 'Server: ON (Live)' : 'Server: OFF (Stopped)'}</span>
          </button>

          {/* Live Song Count Badge */}
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
            <span>🎵</span>
            <span>{songs.length} Tracks</span>
          </div>

          {/* Prominent Add Song Button */}
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

      {/* Filter & Search Controls */}
      <div
        style={{
          display: 'flex',
          gap: '12px',
          alignItems: 'center',
          justifyContent: 'space-between',
          marginBottom: '16px',
          flexWrap: 'wrap',
        }}
      >
        {/* Search Bar */}
        <div style={{ position: 'relative', width: '320px', maxWidth: '100%' }}>
          <Search
            size={15}
            color="var(--text-muted)"
            style={{ position: 'absolute', left: '10px', top: '50%', transform: 'translateY(-50%)' }}
          />
          <input
            type="text"
            className="input-minimal-ctrl"
            placeholder="Search by song, movie, artist..."
            value={searchQuery}
            onChange={(e) => onSearchChange(e.target.value)}
            style={{ paddingLeft: '32px' }}
          />
        </div>

        {/* Genre Filter Pills */}
        <div style={{ display: 'flex', gap: '6px', overflowX: 'auto', paddingBottom: '4px' }}>
          {genres.map((g) => {
            const isSelected =
              g === 'All'
                ? !selectedGenre || selectedGenre === 'All'
                : selectedGenre?.toLowerCase().includes(g.toLowerCase());

            return (
              <button
                key={g}
                onClick={() => onGenreChange(g === 'All' ? 'All' : g)}
                style={{
                  padding: '4px 10px',
                  borderRadius: '16px',
                  border: isSelected ? '1px solid #111827' : '1px solid var(--border-main)',
                  background: isSelected ? '#111827' : '#FFFFFF',
                  color: isSelected ? '#FFFFFF' : '#4B5563',
                  fontSize: '11.5px',
                  fontWeight: isSelected ? 600 : 500,
                  cursor: 'pointer',
                  whiteSpace: 'nowrap',
                  transition: 'all 0.15s',
                }}
              >
                {g}
              </button>
            );
          })}
        </div>
      </div>

      {/* Table Container */}
      <div
        className="table-responsive-wrapper"
        style={{
          background: '#FFFFFF',
          border: '1px solid var(--border-main)',
          borderRadius: '8px',
          overflow: 'hidden',
          boxShadow: '0 1px 2px rgba(0,0,0,0.02)',
        }}
      >
        <table className="table-minimal">
          <thead>
            <tr>
              <th style={{ width: '40px' }}>#</th>
              <th style={{ width: '48px' }}></th>
              <th>Track Title</th>
              <th>Movie / Album</th>
              <th>Artist(s)</th>
              <th>Genre & Mood</th>
              <th style={{ textAlign: 'right', width: '80px' }}>Duration</th>
              <th style={{ textAlign: 'right', width: '100px' }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {songs.length === 0 ? (
              <tr>
                <td colSpan={8} style={{ textAlign: 'center', padding: '36px', color: 'var(--text-muted)' }}>
                  No songs found matching your search.
                </td>
              </tr>
            ) : (
              songs.map((song, idx) => {
                const isCurrent = currentSong?.id === song.id;
                const isCurrentPlaying = isCurrent && isPlaying;

                return (
                  <tr
                    key={song.id}
                    style={{
                      background: isCurrent ? 'rgba(16, 185, 129, 0.04)' : 'transparent',
                    }}
                  >
                    {/* Index or Play Icon */}
                    <td style={{ color: 'var(--text-dim)', fontSize: '12px', textAlign: 'center' }}>
                      <button
                        onClick={() => onPlaySong(song)}
                        className={`play-icon-btn ${isCurrentPlaying ? 'playing' : ''}`}
                        title={isCurrentPlaying ? 'Pause Audio' : 'Play Audio'}
                      >
                        {isCurrentPlaying ? (
                          <Pause size={14} color="var(--emerald)" />
                        ) : (
                          <Play size={14} />
                        )}
                      </button>
                    </td>

                    {/* Artwork Thumbnail */}
                    <td>
                      <img
                        src={song.artworkUrl || '/app_logo.png'}
                        alt={song.title}
                        style={{
                          width: '36px',
                          height: '36px',
                          borderRadius: '4px',
                          objectFit: 'cover',
                          background: 'var(--bg-subtle)',
                        }}
                        onError={(e) => {
                          e.target.src = '/app_logo.png';
                        }}
                      />
                    </td>

                    {/* Title */}
                    <td>
                      <span
                        style={{
                          fontWeight: 600,
                          color: isCurrent ? 'var(--emerald)' : 'var(--text-main)',
                        }}
                      >
                        {song.title}
                      </span>
                    </td>

                    {/* Movie / Album */}
                    <td style={{ color: 'var(--text-muted)' }}>{song.movieName || song.albumName || 'Single'}</td>

                    {/* Artist */}
                    <td style={{ color: 'var(--text-muted)' }}>{song.artistName || 'Unknown'}</td>

                    {/* Genre */}
                    <td>
                      <span
                        style={{
                          display: 'inline-block',
                          fontSize: '11px',
                          padding: '2px 8px',
                          borderRadius: '12px',
                          background: 'var(--bg-subtle)',
                          color: '#4B5563',
                          fontWeight: 500,
                        }}
                      >
                        {song.genre || 'Melody'}
                      </span>
                    </td>

                    {/* Duration */}
                    <td style={{ textAlign: 'right', color: 'var(--text-dim)', fontVariantNumeric: 'tabular-nums' }}>
                      {formatDuration(song.duration)}
                    </td>

                    {/* Actions */}
                    <td style={{ textAlign: 'right' }}>
                      <div style={{ display: 'inline-flex', gap: '4px' }}>
                        <button
                          onClick={() => onEditSong(song)}
                          className="play-icon-btn"
                          title="Edit Metadata"
                          style={{ color: '#6B7280' }}
                        >
                          <Edit3 size={14} />
                        </button>
                        <button
                          onClick={() => onDeleteSong(song)}
                          className="play-icon-btn"
                          title="Delete Song"
                          style={{ color: '#EF4444' }}
                        >
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
