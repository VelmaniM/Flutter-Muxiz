import React, { useState } from 'react';
import { RefreshCw, Trash2, CheckCircle2, AlertTriangle, Smartphone } from 'lucide-react';
import { api } from '../services/api';

export default function CacheSyncView({ onEpochBumped }) {
  const [isSyncing, setIsSyncing] = useState(false);
  const [lastActionMsg, setLastActionMsg] = useState('');

  const handleSyncMobileApp = async () => {
    try {
      setIsSyncing(true);
      const res = await api.wipeAppCache('Manual Studio Sync');
      if (res.success) {
        setLastActionMsg('Sync signal dispatched! Connected mobile apps will refresh their catalog instantly.');
        if (onEpochBumped) onEpochBumped();
      }
    } catch (err) {
      alert('Error triggering sync: ' + err.message);
    } finally {
      setIsSyncing(false);
    }
  };

  const handleClearCatalog = async () => {
    if (!window.confirm('Are you sure you want to clear all songs from the catalog?')) {
      return;
    }
    try {
      const res = await api.wipeCatalog();
      if (res.success) {
        setLastActionMsg('All songs cleared from the catalog.');
        if (onEpochBumped) onEpochBumped();
      }
    } catch (err) {
      alert('Error clearing catalog: ' + err.message);
    }
  };

  return (
    <div className="p-8 space-y-6 max-w-4xl mx-auto">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-slate-900 tracking-tight">App Synchronization</h1>
        <p className="text-xs text-slate-500 mt-0.5">
          Push instant updates to mobile apps and manage catalog state
        </p>
      </div>

      {lastActionMsg && (
        <div className="p-4 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs font-medium flex items-center gap-2">
          <CheckCircle2 className="w-4 h-4 shrink-0 text-emerald-600" />
          <span>{lastActionMsg}</span>
        </div>
      )}

      {/* Sync Card */}
      <div className="p-6 rounded-2xl bg-white border border-slate-200 space-y-4 shadow-xs">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div className="space-y-1">
            <div className="flex items-center gap-2">
              <Smartphone className="w-5 h-5 text-slate-800" />
              <h2 className="text-sm font-bold text-slate-900">Force Mobile App Refresh</h2>
            </div>
            <p className="text-xs text-slate-500 max-w-lg">
              Notifies all connected Flutter mobile apps to immediately download the latest songs and updates.
            </p>
          </div>

          <button
            onClick={handleSyncMobileApp}
            disabled={isSyncing}
            className="px-5 py-2.5 rounded-xl bg-slate-900 hover:bg-slate-800 text-white font-semibold text-xs flex items-center gap-2 transition shadow-xs shrink-0"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isSyncing ? 'animate-spin' : ''}`} />
            <span>Sync Mobile Apps</span>
          </button>
        </div>
      </div>

      {/* Clear Catalog Card */}
      <div className="p-6 rounded-2xl bg-rose-50/60 border border-rose-200 space-y-4 shadow-xs">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div className="space-y-1">
            <div className="flex items-center gap-2 text-rose-800">
              <AlertTriangle className="w-5 h-5 text-rose-600" />
              <h2 className="text-sm font-bold">Clear Entire Catalog</h2>
            </div>
            <p className="text-xs text-rose-600/80 max-w-lg">
              Deletes all songs from the active mobile catalog.
            </p>
          </div>

          <button
            onClick={handleClearCatalog}
            className="px-4 py-2 rounded-xl bg-rose-600 hover:bg-rose-700 text-white text-xs font-semibold transition shrink-0 flex items-center gap-1.5 shadow-xs"
          >
            <Trash2 className="w-3.5 h-3.5" />
            <span>Clear Catalog</span>
          </button>
        </div>
      </div>
    </div>
  );
}
