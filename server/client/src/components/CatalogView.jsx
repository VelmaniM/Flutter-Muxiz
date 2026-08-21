import React, { useState, useEffect } from 'react';
import {
  Search,
  Play,
  Pause,
  Trash2,
  Edit2,
  Music,
  X,
  RefreshCw,
  Plus,
} from 'lucide-react';
import { api } from '../services/api';

export default function CatalogView({ currentSong, isPlaying, onPlaySong, onCatalogChanged, setActiveTab }) {
  const [songs, setSongs] = useState([]);
  const [search, setSearch] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [editingSong, setEditingSong] = useState(null);

  const fetchSongs = async () => {
    try {
      setIsLoading(true);
      const res = await api.getSongs({ search, limit: 100 });
      if (res.success) {
        setSongs(res.songs || []);
      }
    } catch (err) {
      console.error('Fetch songs error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchSongs();
  }, [search]);

  const handleDelete = async (id, title) => {
    if (!window.confirm(`Are you sure you want to delete "${title}"?`)) return;
    try {
      const res = await api.deleteSong(id, false);
      if (res.success) {
        setSongs((prev) => prev.filter((s) => (s.id || s._id) !== id));
        if (onCatalogChanged) onCatalogChanged();
      }
    } catch (err) {
      alert('Failed to delete song: ' + err.message);
    }
  };

  const handleSaveEdit = async (e) => {
    e.preventDefault();
    if (!editingSong) return;
    const id = editingSong.id || editingSong._id;
    const backupSongs = [...songs];
    const updatedDraft = { ...editingSong };

    // 0ms Immediate Optimistic UI update
    setSongs((prev) =>
      prev.map((s) => ((s.id || s._id) === id ? { ...s, ...updatedDraft } : s))
    );
    setEditingSong(null);

    try {
      const res = await api.updateSong(id, updatedDraft);
      if (res.success && res.song) {
        setSongs((prev) =>
          prev.map((s) => ((s.id || s._id) === id ? res.song : s))
        );
        if (onCatalogChanged) onCatalogChanged();
      } else {
        setSongs(backupSongs);
        alert(res.message || 'Failed to update song details');
      }
    } catch (err) {
      setSongs(backupSongs);
      alert('Failed to update song: ' + err.message);
    }
  };

  return (
    <div className="p-8 space-y-6 max-w-6xl mx-auto">
      {/* Top Header & Search Bar */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-slate-900 tracking-tight">Song Catalog</h1>
          <p className="text-xs text-slate-500 mt-0.5">
            {songs.length} tracks available in your music streaming catalog
          </p>
        </div>

        <div className="flex items-center gap-3">
          {/* Search Input */}
          <div className="relative w-64">
            <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Search title, artist, movie..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full bg-white border border-slate-200 rounded-lg pl-9 pr-3 py-1.5 text-xs text-slate-900 placeholder-slate-400 focus:outline-none focus:border-slate-400 font-medium shadow-xs"
            />
          </div>

          <button
            onClick={fetchSongs}
            className="p-2 bg-white hover:bg-slate-50 border border-slate-200 rounded-lg text-slate-600 hover:text-slate-900 transition shadow-xs"
            title="Refresh List"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isLoading ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {/* Clean Songs Table */}
      <div className="rounded-2xl border border-slate-200 bg-white overflow-hidden shadow-xs">
        <table className="w-full text-left text-xs">
          <thead className="bg-slate-50/75 border-b border-slate-100 text-[11px] font-semibold text-slate-500 select-none">
            <tr>
              <th className="py-3 px-4 w-12 text-center">#</th>
              <th className="py-3 px-4">Title</th>
              <th className="py-3 px-4">Artist</th>
              <th className="py-3 px-4">Album / Movie</th>
              <th className="py-3 px-4">Genre</th>
              <th className="py-3 px-4 text-right">Actions</th>
            </tr>
          </thead>

          <tbody className="divide-y divide-slate-100 text-slate-700">
            {songs.length === 0 ? (
              <tr>
                <td colSpan="6" className="py-12 text-center text-slate-400 text-xs">
                  {isLoading ? 'Loading songs...' : 'No songs found in catalog.'}
                </td>
              </tr>
            ) : (
              songs.map((song, index) => {
                const songId = song.id || song._id;
                const isThisPlaying = currentSong && (currentSong.id === songId || currentSong._id === songId) && isPlaying;
                return (
                  <tr
                    key={songId || index}
                    className="hover:bg-slate-50/80 transition group"
                  >
                    {/* Index / Play Button */}
                    <td className="py-3 px-4 text-center text-slate-400 font-medium">
                      <button
                        onClick={() => onPlaySong && onPlaySong(song)}
                        className="w-7 h-7 rounded-full flex items-center justify-center bg-slate-100 group-hover:bg-slate-900 group-hover:text-white text-slate-600 transition mx-auto"
                      >
                        {isThisPlaying ? (
                          <Pause className="w-3.5 h-3.5 text-slate-900 group-hover:text-white" />
                        ) : (
                          <Play className="w-3.5 h-3.5 ml-0.5" />
                        )}
                      </button>
                    </td>

                    {/* Track Info with Artwork */}
                    <td className="py-3 px-4">
                      <div className="flex items-center gap-3">
                        <div className="w-9 h-9 rounded-lg bg-slate-100 overflow-hidden shrink-0 border border-slate-200 flex items-center justify-center">
                          {song.artworkUrl ? (
                            <img
                              src={song.artworkUrl}
                              alt=""
                              className="w-full h-full object-cover"
                              onError={(e) => (e.target.src = '')}
                            />
                          ) : (
                            <Music className="w-4 h-4 text-slate-400" />
                          )}
                        </div>
                        <div>
                          <div className="font-semibold text-slate-900">{song.title}</div>
                          <div className="text-[11px] text-slate-400">{song.language || 'Tamil'}</div>
                        </div>
                      </div>
                    </td>

                    {/* Artist */}
                    <td className="py-3 px-4 text-slate-600 font-medium">{song.artist || song.artistName}</td>

                    {/* Album */}
                    <td className="py-3 px-4 text-slate-500">{song.album || song.movieName || 'Single'}</td>

                    {/* Genre */}
                    <td className="py-3 px-4">
                      <span className="text-[11px] font-medium px-2.5 py-0.5 rounded-full bg-slate-100 text-slate-600">
                        {song.genre || 'Melody'}
                      </span>
                    </td>

                    {/* Actions */}
                    <td className="py-3 px-4 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        <button
                          onClick={() => setEditingSong(song)}
                          className="p-1.5 rounded-lg hover:bg-slate-100 text-slate-400 hover:text-slate-700 transition"
                          title="Edit Song"
                        >
                          <Edit2 className="w-3.5 h-3.5" />
                        </button>
                        <button
                          onClick={() => handleDelete(songId, song.title)}
                          className="p-1.5 rounded-lg hover:bg-rose-50 text-slate-400 hover:text-rose-600 transition"
                          title="Delete Song"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
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

      {/* Edit Song Modal */}
      {editingSong && (
        <div className="fixed inset-0 bg-slate-900/30 backdrop-blur-xs flex items-center justify-center p-4 z-50">
          <div className="bg-white border border-slate-200 rounded-2xl p-6 w-full max-w-lg space-y-4 shadow-xl">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <h2 className="text-sm font-bold text-slate-900">Edit Song Details</h2>
              <button onClick={() => setEditingSong(null)} className="text-slate-400 hover:text-slate-600">
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleSaveEdit} className="space-y-3.5">
              <div>
                <label className="text-[11px] text-slate-500 font-medium block mb-1">Song Title</label>
                <input
                  type="text"
                  value={editingSong.title || ''}
                  onChange={(e) => setEditingSong({ ...editingSong, title: e.target.value })}
                  className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-2 text-xs text-slate-900 focus:bg-white focus:outline-none focus:border-slate-400 font-medium"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-[11px] text-slate-500 font-medium block mb-1">Artist</label>
                  <input
                    type="text"
                    value={editingSong.artistName || editingSong.artist || ''}
                    onChange={(e) => setEditingSong({ ...editingSong, artistName: e.target.value, artist: e.target.value })}
                    className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-2 text-xs text-slate-900 focus:bg-white focus:outline-none focus:border-slate-400"
                  />
                </div>

                <div>
                  <label className="text-[11px] text-slate-500 font-medium block mb-1">Album / Movie</label>
                  <input
                    type="text"
                    value={editingSong.movieName || editingSong.albumName || ''}
                    onChange={(e) => setEditingSong({ ...editingSong, movieName: e.target.value, albumName: e.target.value, album: e.target.value })}
                    className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-2 text-xs text-slate-900 focus:bg-white focus:outline-none focus:border-slate-400"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-[11px] text-slate-500 font-medium block mb-1">Genre</label>
                  <input
                    type="text"
                    value={editingSong.genre || ''}
                    onChange={(e) => setEditingSong({ ...editingSong, genre: e.target.value })}
                    className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-2 text-xs text-slate-900 focus:bg-white focus:outline-none focus:border-slate-400"
                  />
                </div>

                <div>
                  <label className="text-[11px] text-slate-500 font-medium block mb-1">Language</label>
                  <input
                    type="text"
                    value={editingSong.language || ''}
                    onChange={(e) => setEditingSong({ ...editingSong, language: e.target.value })}
                    className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-2 text-xs text-slate-900 focus:bg-white focus:outline-none focus:border-slate-400"
                  />
                </div>
              </div>

              <div>
                <label className="text-[11px] text-slate-500 font-medium block mb-1">Cover Artwork URL</label>
                <input
                  type="text"
                  value={editingSong.artworkUrl || ''}
                  onChange={(e) => setEditingSong({ ...editingSong, artworkUrl: e.target.value })}
                  className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-2 text-xs text-slate-900 font-mono text-[11px] focus:bg-white focus:outline-none focus:border-slate-400"
                />
              </div>

              <div className="flex justify-end gap-2.5 pt-3">
                <button
                  type="button"
                  onClick={() => setEditingSong(null)}
                  className="px-4 py-2 rounded-lg border border-slate-200 hover:bg-slate-50 text-slate-600 text-xs font-medium transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-lg bg-slate-900 hover:bg-slate-800 text-white text-xs font-semibold transition shadow-xs"
                >
                  Save Changes
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
