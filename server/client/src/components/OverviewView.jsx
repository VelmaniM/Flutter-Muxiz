import React, { useState, useEffect } from 'react';
import { Music, UserCheck, Disc, Users, Play, Pause, UploadCloud, RefreshCw, ArrowRight } from 'lucide-react';
import { api } from '../services/api';

export default function OverviewView({ metrics, setActiveTab, onWipeCache, currentSong, isPlaying, onPlaySong }) {
  const [recentSongs, setRecentSongs] = useState([]);

  useEffect(() => {
    api.getSongs({ limit: 5 }).then((res) => {
      if (res.success) setRecentSongs(res.songs || []);
    }).catch(() => {});
  }, [metrics]);

  const cards = [
    {
      title: 'Total Songs',
      value: metrics?.songs || 0,
      sub: 'Active in mobile catalog',
      icon: Music,
      action: () => setActiveTab('catalog'),
    },
    {
      title: 'Artists',
      value: metrics?.artists || 0,
      sub: 'Featured creators',
      icon: UserCheck,
      action: () => setActiveTab('artists'),
    },
    {
      title: 'Albums & Movies',
      value: metrics?.albums || 0,
      sub: 'Organized releases',
      icon: Disc,
      action: () => setActiveTab('catalog'),
    },
    {
      title: 'Registered Users',
      value: metrics?.users || 0,
      sub: 'Active mobile listeners',
      icon: Users,
      action: () => setActiveTab('users'),
    },
  ];

  return (
    <div className="p-8 space-y-8 max-w-6xl mx-auto">
      {/* Welcome Banner */}
      <div className="p-6 rounded-2xl bg-white border border-slate-200 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 shadow-xs">
        <div className="space-y-1">
          <h1 className="text-xl font-bold text-slate-900 tracking-tight">Admin Console Dashboard</h1>
          <p className="text-xs text-slate-500">
            Upload new tracks, manage catalog, artists and user accounts with real-time mobile app sync.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => setActiveTab('ingest')}
            className="px-4 py-2 rounded-lg bg-slate-900 hover:bg-slate-800 text-white font-semibold text-xs flex items-center gap-2 transition shadow-xs"
          >
            <UploadCloud className="w-4 h-4" />
            <span>Upload New Song</span>
          </button>
          <button
            onClick={() => setActiveTab('sync')}
            className="px-3.5 py-2 rounded-lg bg-white hover:bg-slate-50 border border-slate-200 text-slate-700 text-xs font-medium flex items-center gap-1.5 transition shadow-xs"
          >
            <RefreshCw className="w-3.5 h-3.5 text-slate-600" />
            <span>App Sync</span>
          </button>
        </div>
      </div>

      {/* Stats Grid - 4 Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {cards.map((card, i) => {
          const Icon = card.icon;
          return (
            <div
              key={i}
              onClick={card.action}
              className="p-5 rounded-2xl bg-white border border-slate-200 hover:border-slate-300 transition flex items-center justify-between cursor-pointer shadow-xs group"
            >
              <div className="space-y-1">
                <span className="text-xs font-medium text-slate-500">{card.title}</span>
                <div className="text-2xl font-bold text-slate-900">{card.value}</div>
                <div className="text-[11px] text-slate-400">{card.sub}</div>
              </div>
              <div className="p-3 rounded-xl bg-slate-50 group-hover:bg-slate-100 text-slate-700 transition">
                <Icon className="w-5 h-5" />
              </div>
            </div>
          );
        })}
      </div>

      {/* Recent Releases Section */}
      <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-xs">
        <div className="p-5 border-b border-slate-100 flex items-center justify-between">
          <div>
            <h2 className="text-sm font-bold text-slate-900">Recent Songs in Catalog</h2>
            <p className="text-xs text-slate-400 mt-0.5">Recently added tracks streaming on mobile</p>
          </div>
          <button
            onClick={() => setActiveTab('catalog')}
            className="text-xs font-medium text-slate-600 hover:text-slate-900 flex items-center gap-1 transition"
          >
            <span>View All</span>
            <ArrowRight className="w-3.5 h-3.5" />
          </button>
        </div>

        {recentSongs.length === 0 ? (
          <div className="p-10 text-center text-xs text-slate-400">
            No songs uploaded yet. Click "Upload New Song" to add your first track.
          </div>
        ) : (
          <div className="divide-y divide-slate-100">
            {recentSongs.map((song) => {
              const isThisPlaying = currentSong && (currentSong.id === song.id || currentSong._id === song._id) && isPlaying;
              return (
                <div
                  key={song.id || song._id}
                  className="p-4 flex items-center justify-between hover:bg-slate-50 transition"
                >
                  <div className="flex items-center gap-3.5">
                    <button
                      onClick={() => onPlaySong && onPlaySong(song)}
                      className="w-8 h-8 rounded-full flex items-center justify-center bg-slate-100 hover:bg-slate-900 hover:text-white text-slate-700 transition shrink-0"
                    >
                      {isThisPlaying ? <Pause className="w-3.5 h-3.5" /> : <Play className="w-3.5 h-3.5 ml-0.5" />}
                    </button>
                    <div className="w-10 h-10 rounded-lg bg-slate-100 overflow-hidden shrink-0 border border-slate-200 flex items-center justify-center">
                      {song.artworkUrl ? (
                        <img src={song.artworkUrl} alt="" className="w-full h-full object-cover" />
                      ) : (
                        <Music className="w-4 h-4 text-slate-400" />
                      )}
                    </div>
                    <div>
                      <div className="text-xs font-bold text-slate-900">{song.title}</div>
                      <div className="text-[11px] text-slate-500">{song.artist || song.artistName} • {song.album || song.movieName || 'Single'}</div>
                    </div>
                  </div>

                  <span className="text-xs font-medium text-slate-500 px-2.5 py-1 rounded-full bg-slate-50 border border-slate-100">
                    {song.genre || 'Melody'}
                  </span>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
