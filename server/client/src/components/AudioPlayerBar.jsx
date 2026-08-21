import React, { useRef, useState, useEffect } from 'react';
import { Play, Pause, Volume2, VolumeX, Music, X, AlertCircle } from 'lucide-react';

export default function AudioPlayerBar({ song, isPlaying, onTogglePlay, onClose }) {
  const audioRef = useRef(null);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [volume, setVolume] = useState(1);
  const [isMuted, setIsMuted] = useState(false);
  const [hasError, setHasError] = useState(false);

  // Compute best playable stream URL (Proxy or Direct)
  const getStreamUrl = (item) => {
    if (!item) return '';
    const fileId = item.storage?.fileId;
    if (fileId) {
      return `/api/v1/songs/stream/${fileId}`;
    }
    const rawUrl = item.audioUrl || item.storage?.directStreamUrl || '';
    if (rawUrl.includes('id=')) {
      const match = rawUrl.match(/id=([a-zA-Z0-9_-]+)/);
      if (match && match[1]) {
        return `/api/v1/songs/stream/${match[1]}`;
      }
    }
    return rawUrl;
  };

  const streamSrc = getStreamUrl(song);

  useEffect(() => {
    setHasError(false);
    if (audioRef.current && song) {
      audioRef.current.load();
      if (isPlaying) {
        audioRef.current
          .play()
          .catch((err) => {
            console.warn('Playback error (retrying with direct link):', err);
            // Fallback directly to raw URL if proxy had an issue
            if (audioRef.current && song.audioUrl) {
              audioRef.current.src = song.audioUrl;
              audioRef.current.play().catch(() => setHasError(true));
            }
          });
      }
    }
  }, [song]);

  useEffect(() => {
    if (audioRef.current) {
      if (isPlaying) {
        audioRef.current.play().catch(() => {});
      } else {
        audioRef.current.pause();
      }
    }
  }, [isPlaying]);

  const handleTimeUpdate = () => {
    if (audioRef.current) {
      setCurrentTime(audioRef.current.currentTime);
      setDuration(audioRef.current.duration || 0);
    }
  };

  const handleSeek = (e) => {
    const newTime = Number(e.target.value);
    if (audioRef.current) {
      audioRef.current.currentTime = newTime;
      setCurrentTime(newTime);
    }
  };

  const formatTime = (secs) => {
    if (!secs || isNaN(secs)) return '0:00';
    const m = Math.floor(secs / 60);
    const s = Math.floor(secs % 60);
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  };

  if (!song) return null;

  return (
    <div className="fixed bottom-0 left-0 right-0 h-20 bg-white border-t border-slate-200 px-8 flex items-center justify-between z-40 select-none shadow-lg">
      <audio
        ref={audioRef}
        src={streamSrc}
        onTimeUpdate={handleTimeUpdate}
        onEnded={onTogglePlay}
        onError={() => setHasError(true)}
      />

      {/* Song Info */}
      <div className="flex items-center gap-3 w-72">
        <div className="w-12 h-12 rounded-xl bg-slate-100 border border-slate-200 overflow-hidden shrink-0 flex items-center justify-center">
          {song.artworkUrl ? (
            <img src={song.artworkUrl} alt="Art" className="w-full h-full object-cover" />
          ) : (
            <Music className="w-5 h-5 text-slate-400" />
          )}
        </div>
        <div className="truncate">
          <div className="text-xs font-bold text-slate-900 truncate">{song.title}</div>
          <div className="text-[11px] text-slate-500 truncate">{song.artist || song.artistName}</div>
          {hasError && (
            <div className="text-[10px] text-rose-500 flex items-center gap-1 mt-0.5">
              <AlertCircle className="w-3 h-3" /> Audio load issue
            </div>
          )}
        </div>
      </div>

      {/* Center Controls & Scrubber */}
      <div className="flex flex-col items-center gap-1.5 flex-1 max-w-xl">
        <div className="flex items-center gap-4">
          <button
            onClick={onTogglePlay}
            className="w-10 h-10 rounded-full bg-slate-900 hover:bg-slate-800 text-white flex items-center justify-center transition shadow-xs"
          >
            {isPlaying ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4 ml-0.5" />}
          </button>
        </div>

        <div className="flex items-center gap-3 w-full text-[11px] font-mono text-slate-500">
          <span>{formatTime(currentTime)}</span>
          <input
            type="range"
            min="0"
            max={duration || 100}
            value={currentTime}
            onChange={handleSeek}
            className="w-full h-1 bg-slate-200 rounded-lg appearance-none cursor-pointer accent-slate-900"
          />
          <span>{formatTime(duration)}</span>
        </div>
      </div>

      {/* Volume & Close */}
      <div className="flex items-center gap-3 w-72 justify-end">
        <button
          onClick={() => {
            if (audioRef.current) {
              audioRef.current.muted = !isMuted;
              setIsMuted(!isMuted);
            }
          }}
          className="text-slate-500 hover:text-slate-900"
        >
          {isMuted ? <VolumeX className="w-4 h-4" /> : <Volume2 className="w-4 h-4" />}
        </button>

        <input
          type="range"
          min="0"
          max="1"
          step="0.01"
          value={isMuted ? 0 : volume}
          onChange={(e) => {
            const v = Number(e.target.value);
            setVolume(v);
            if (audioRef.current) audioRef.current.volume = v;
          }}
          className="w-20 h-1 bg-slate-200 rounded-lg appearance-none cursor-pointer accent-slate-900"
        />

        <button onClick={onClose} className="text-slate-400 hover:text-slate-700 ml-2">
          <X className="w-4 h-4" />
        </button>
      </div>
    </div>
  );
}
