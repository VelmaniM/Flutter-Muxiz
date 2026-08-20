'use client';

import React, { useRef, useEffect, useState } from 'react';
import { Play, Pause, SkipBack, SkipForward, Volume2, VolumeX } from 'lucide-react';

export default function AudioPlayerBar({
  currentSong,
  isPlaying,
  setIsPlaying,
  onNext,
  onPrev,
}) {
  const audioRef = useRef(null);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [volume, setVolume] = useState(0.9);
  const [isMuted, setIsMuted] = useState(false);

  useEffect(() => {
    if (!audioRef.current || !currentSong) return;

    audioRef.current.src = currentSong.audioUrl;
    if (isPlaying) {
      audioRef.current.play().catch(() => setIsPlaying(false));
    }
  }, [currentSong]);

  useEffect(() => {
    if (!audioRef.current) return;
    if (isPlaying) {
      audioRef.current.play().catch(() => setIsPlaying(false));
    } else {
      audioRef.current.pause();
    }
  }, [isPlaying]);

  useEffect(() => {
    if (audioRef.current) {
      audioRef.current.volume = isMuted ? 0 : volume;
    }
  }, [volume, isMuted]);

  const togglePlay = () => {
    setIsPlaying(!isPlaying);
  };

  const handleSeek = (e) => {
    const time = parseFloat(e.target.value);
    setCurrentTime(time);
    if (audioRef.current) {
      audioRef.current.currentTime = time;
    }
  };

  const formatTime = (secs) => {
    if (isNaN(secs) || secs === 0) return '0:00';
    const m = Math.floor(secs / 60);
    const s = Math.floor(secs % 60);
    return `${m}:${s < 10 ? '0' + s : s}`;
  };

  if (!currentSong) return null;

  return (
    <div className="player-bar-container">
      <audio
        ref={audioRef}
        onTimeUpdate={() => setCurrentTime(audioRef.current?.currentTime || 0)}
        onLoadedMetadata={() => setDuration(audioRef.current?.duration || 0)}
        onEnded={onNext}
      />

      {/* Left: Track Info */}
      <div className="player-track-info">
        <img
          src={currentSong.artworkUrl || '/app_logo.png'}
          alt={currentSong.title}
          style={{
            width: '44px',
            height: '44px',
            borderRadius: '4px',
            objectFit: 'cover',
            background: 'var(--bg-subtle)',
            flexShrink: 0,
          }}
          onError={(e) => {
            e.target.src = '/app_logo.png';
          }}
        />
        <div style={{ overflow: 'hidden' }}>
          <p
            style={{
              fontSize: '13px',
              fontWeight: 600,
              color: 'var(--text-main)',
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {currentSong.title}
          </p>
          <p
            style={{
              fontSize: '11.5px',
              color: 'var(--text-muted)',
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {currentSong.artistName || currentSong.movieName || 'Single'}
          </p>
        </div>
      </div>

      {/* Center: Controls & Progress */}
      <div className="player-controls">
        {/* Buttons */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
          <button onClick={onPrev} className="play-icon-btn" title="Previous Track">
            <SkipBack size={15} />
          </button>
          <button
            onClick={togglePlay}
            style={{
              width: '32px',
              height: '32px',
              borderRadius: '50%',
              background: '#111827',
              color: '#FFFFFF',
              border: 'none',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              transition: 'transform 0.1s',
            }}
            title={isPlaying ? 'Pause' : 'Play'}
          >
            {isPlaying ? <Pause size={15} /> : <Play size={15} style={{ marginLeft: '2px' }} />}
          </button>
          <button onClick={onNext} className="play-icon-btn" title="Next Track">
            <SkipForward size={15} />
          </button>
        </div>

        {/* Progress Bar */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', width: '100%' }}>
          <span style={{ fontSize: '11px', color: 'var(--text-dim)', fontVariantNumeric: 'tabular-nums', width: '32px' }}>
            {formatTime(currentTime)}
          </span>
          <input
            type="range"
            min="0"
            max={duration || 100}
            value={currentTime}
            onChange={handleSeek}
            className="range-minimal"
          />
          <span
            style={{
              fontSize: '11px',
              color: 'var(--text-dim)',
              fontVariantNumeric: 'tabular-nums',
              width: '32px',
              textAlign: 'right',
            }}
          >
            {formatTime(duration)}
          </span>
        </div>
      </div>

      {/* Right: Volume */}
      <div className="player-volume-control">
        <button onClick={() => setIsMuted(!isMuted)} className="play-icon-btn" style={{ padding: '4px' }}>
          {isMuted || volume === 0 ? <VolumeX size={16} /> : <Volume2 size={16} />}
        </button>
        <input
          type="range"
          min="0"
          max="1"
          step="0.01"
          value={isMuted ? 0 : volume}
          onChange={(e) => {
            setVolume(parseFloat(e.target.value));
            setIsMuted(false);
          }}
          className="range-minimal"
          style={{ width: '80px' }}
        />
      </div>
    </div>
  );
}
