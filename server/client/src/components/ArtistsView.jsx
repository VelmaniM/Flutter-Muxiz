import React, { useState, useEffect } from 'react';
import { Search, UserCheck, Edit2, Trash2, X, Plus, Music, RefreshCw } from 'lucide-react';
import { api } from '../services/api';

export default function ArtistsView({ onArtistChanged }) {
  const [artists, setArtists] = useState([]);
  const [search, setSearch] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [editingArtist, setEditingArtist] = useState(null);
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState('');
  const [newArtistModal, setNewArtistModal] = useState(false);
  const [newArtistData, setNewArtistData] = useState({ name: '', imageUrl: '', bio: '' });

  const fetchArtists = async () => {
    try {
      setIsLoading(true);
      const res = await api.getArtists({ search });
      if (res.success) {
        setArtists(res.artists || []);
      }
    } catch (err) {
      console.error('Fetch artists error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchArtists();
  }, [search]);

  const handleSaveEdit = async (e) => {
    e.preventDefault();
    if (!editingArtist) return;
    setIsSaving(true);
    setSaveError('');
    try {
      const payload = {
        ...editingArtist,
        originalName: editingArtist._originalName || editingArtist.name, // for name-based lookup
      };
      const res = await api.updateArtist(editingArtist.id || editingArtist._id, payload);
      if (res.success) {
        // Update local list immediately — optimistic update
        setArtists((prev) =>
          prev.map((a) =>
            (a.id || a._id) === (editingArtist.id || editingArtist._id) || a.name === (editingArtist._originalName || editingArtist.name)
              ? { ...a, ...editingArtist, ...(res.artist || {}) }
              : a
          )
        );
        setEditingArtist(null);
        if (onArtistChanged) onArtistChanged();
      } else {
        setSaveError(res.message || 'Failed to save. Try again.');
      }
    } catch (err) {
      setSaveError('Save failed: ' + err.message);
    } finally {
      setIsSaving(false);
    }
  };

  const handleCreateArtist = async (e) => {
    e.preventDefault();
    if (!newArtistData.name.trim()) return;
    try {
      const res = await api.createArtist(newArtistData);
      if (res.success) {
        setArtists((prev) => [res.artist, ...prev]);
        setNewArtistModal(false);
        setNewArtistData({ name: '', imageUrl: '', bio: '' });
        if (onArtistChanged) onArtistChanged();
      }
    } catch (err) {
      alert('Failed to create artist: ' + err.message);
    }
  };

  const handleDeleteArtist = async (id, name) => {
    if (!window.confirm(`Are you sure you want to delete artist "${name}" and their associated songs?`)) return;
    try {
      const res = await api.deleteArtist(name);
      if (res.success) {
        setArtists((prev) => prev.filter((a) => (a.id || a._id) !== id && a.name !== name));
        if (onArtistChanged) onArtistChanged();
      }
    } catch (err) {
      alert('Failed to delete artist: ' + err.message);
    }
  };

  return (
    <div className="p-8 space-y-6 max-w-6xl mx-auto">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-slate-900 tracking-tight">Artist Management</h1>
          <p className="text-xs text-slate-500 mt-0.5">
            {artists.length} artists in your music catalog
          </p>
        </div>

        <div className="flex items-center gap-3">
          <div className="relative w-64">
            <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Search artist name..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full bg-white border border-slate-200 rounded-lg pl-9 pr-3 py-1.5 text-xs text-slate-900 placeholder-slate-400 focus:outline-none focus:border-slate-400 font-medium shadow-xs"
            />
          </div>

          <button
            onClick={() => setNewArtistModal(true)}
            className="px-3.5 py-1.5 rounded-lg bg-slate-900 hover:bg-slate-800 text-white font-semibold text-xs flex items-center gap-1.5 transition shadow-xs shrink-0"
          >
            <Plus className="w-3.5 h-3.5" />
            <span>Add Artist</span>
          </button>

          <button
            onClick={fetchArtists}
            className="p-2 bg-white hover:bg-slate-50 border border-slate-200 rounded-lg text-slate-600 hover:text-slate-900 transition shadow-xs"
            title="Refresh List"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isLoading ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {/* Artists Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-5">
        {artists.length === 0 ? (
          <div className="col-span-full p-12 text-center text-xs text-slate-400 bg-white rounded-2xl border border-slate-200">
            {isLoading ? 'Loading artists...' : 'No artists found. Upload songs or add artists manually.'}
          </div>
        ) : (
          artists.map((artist) => (
            <div
              key={artist.id || artist._id || artist.name}
              className="p-5 rounded-2xl bg-white border border-slate-200 hover:border-slate-300 transition shadow-xs flex flex-col items-center text-center relative group"
            >
              {/* Actions Dropdown */}
              <div className="absolute top-3 right-3 flex items-center gap-1 opacity-0 group-hover:opacity-100 transition">
                <button
                  onClick={() => {
                setEditingArtist({ ...artist, _originalName: artist.name });
                setSaveError('');
              }}
                  className="p-1 rounded-md bg-slate-100 hover:bg-slate-200 text-slate-600"
                  title="Edit Artist"
                >
                  <Edit2 className="w-3 h-3" />
                </button>
                <button
                  onClick={() => handleDeleteArtist(artist.id || artist._id, artist.name)}
                  className="p-1 rounded-md bg-rose-50 hover:bg-rose-100 text-rose-600"
                  title="Delete Artist"
                >
                  <Trash2 className="w-3 h-3" />
                </button>
              </div>

              {/* Avatar */}
              <div className="w-20 h-20 rounded-full bg-slate-100 border border-slate-200 overflow-hidden mb-3.5 flex items-center justify-center shadow-xs">
                {artist.imageUrl ? (
                  <img
                    src={artist.imageUrl}
                    alt={artist.name}
                    className="w-full h-full object-cover"
                    onError={(e) => (e.target.src = '')}
                  />
                ) : (
                  <UserCheck className="w-8 h-8 text-slate-400" />
                )}
              </div>

              <div className="font-bold text-sm text-slate-900 mb-0.5 line-clamp-1">{artist.name}</div>
              <div className="text-xs text-slate-400 flex items-center gap-1.5 mb-3">
                <Music className="w-3 h-3" />
                <span>{artist.songsCount || 0} Tracks</span>
              </div>

              <button
                onClick={() => {
                  setEditingArtist({ ...artist, _originalName: artist.name });
                  setSaveError('');
                }}
                className="w-full py-1.5 rounded-lg bg-slate-50 hover:bg-slate-100 border border-slate-200 text-slate-700 text-xs font-medium transition"
              >
                Edit Profile
              </button>
            </div>
          ))
        )}
      </div>

      {/* Add Artist Modal */}
      {newArtistModal && (
        <div className="fixed inset-0 bg-slate-900/30 backdrop-blur-xs flex items-center justify-center p-4 z-50">
          <div className="bg-white border border-slate-200 rounded-2xl p-6 w-full max-w-md space-y-4 shadow-xl">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <h2 className="text-sm font-bold text-slate-900">Add New Artist</h2>
              <button onClick={() => setNewArtistModal(false)} className="text-slate-400 hover:text-slate-600">
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleCreateArtist} className="space-y-3.5">
              <div>
                <label className="text-[11px] text-slate-500 font-medium block mb-1">Artist Name</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Anirudh Ravichander"
                  value={newArtistData.name}
                  onChange={(e) => setNewArtistData({ ...newArtistData, name: e.target.value })}
                  className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-2 text-xs text-slate-900 focus:bg-white focus:outline-none focus:border-slate-400 font-medium"
                />
              </div>

              <div>
                <label className="text-[11px] text-slate-500 font-medium block mb-1">Artist Portrait URL</label>
                <input
                  type="text"
                  placeholder="https://..."
                  value={newArtistData.imageUrl}
                  onChange={(e) => setNewArtistData({ ...newArtistData, imageUrl: e.target.value })}
                  className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-2 text-xs text-slate-900 focus:bg-white focus:outline-none focus:border-slate-400 font-mono text-[11px]"
                />
              </div>

              <div>
                <label className="text-[11px] text-slate-500 font-medium block mb-1">Bio / Note</label>
                <textarea
                  rows="2"
                  placeholder="Short bio..."
                  value={newArtistData.bio}
                  onChange={(e) => setNewArtistData({ ...newArtistData, bio: e.target.value })}
                  className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-2 text-xs text-slate-900 focus:bg-white focus:outline-none focus:border-slate-400"
                />
              </div>

              <div className="flex justify-end gap-2.5 pt-3">
                <button
                  type="button"
                  onClick={() => setNewArtistModal(false)}
                  className="px-4 py-2 rounded-lg border border-slate-200 hover:bg-slate-50 text-slate-600 text-xs font-medium transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-lg bg-slate-900 hover:bg-slate-800 text-white text-xs font-semibold transition shadow-xs"
                >
                  Create Artist
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Edit Artist Modal */}
      {editingArtist && (
        <div className="fixed inset-0 bg-slate-900/30 backdrop-blur-xs flex items-center justify-center p-4 z-50">
          <div className="bg-white border border-slate-200 rounded-2xl p-6 w-full max-w-md space-y-4 shadow-xl">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <h2 className="text-sm font-bold text-slate-900">Edit Artist Profile</h2>
              <button onClick={() => setEditingArtist(null)} className="text-slate-400 hover:text-slate-600">
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleSaveEdit} className="space-y-3.5">
              <div>
                <label className="text-[11px] text-slate-500 font-medium block mb-1">Artist Name</label>
                <input
                  type="text"
                  required
                  value={editingArtist.name || ''}
                  onChange={(e) => setEditingArtist({ ...editingArtist, name: e.target.value })}
                  className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-2 text-xs text-slate-900 focus:bg-white focus:outline-none focus:border-blue-400 font-medium transition"
                />
              </div>

              <div>
                <label className="text-[11px] text-slate-500 font-medium block mb-1">Portrait Photo URL</label>
                <input
                  type="text"
                  value={editingArtist.imageUrl || ''}
                  onChange={(e) => setEditingArtist({ ...editingArtist, imageUrl: e.target.value })}
                  className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-2 text-xs text-slate-900 focus:bg-white focus:outline-none focus:border-blue-400 font-mono text-[11px] transition"
                />
              </div>

              <div>
                <label className="text-[11px] text-slate-500 font-medium block mb-1">Bio</label>
                <textarea
                  rows="2"
                  value={editingArtist.bio || ''}
                  onChange={(e) => setEditingArtist({ ...editingArtist, bio: e.target.value })}
                  className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-2 text-xs text-slate-900 focus:bg-white focus:outline-none focus:border-blue-400 transition"
                />
              </div>

              {/* Inline error */}
              {saveError && (
                <p className="text-[11px] text-rose-600 font-medium px-1">{saveError}</p>
              )}

              <div className="flex justify-end gap-2.5 pt-3">
                <button
                  type="button"
                  onClick={() => { setEditingArtist(null); setSaveError(''); }}
                  className="px-4 py-2 rounded-lg border border-slate-200 hover:bg-slate-50 text-slate-600 text-xs font-medium transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSaving || !editingArtist.name?.trim()}
                  className="px-4 py-2 rounded-lg bg-slate-900 hover:bg-slate-800 disabled:opacity-50 text-white text-xs font-semibold transition shadow-xs flex items-center gap-1.5"
                >
                  {isSaving ? (
                    <><RefreshCw className="w-3 h-3 animate-spin" /> Saving...</>
                  ) : (
                    'Save Changes'
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
