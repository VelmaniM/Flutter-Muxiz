import React from 'react';
import { RefreshCw } from 'lucide-react';

export default function Header({ metrics, onRefresh, isRefreshing }) {
  return (
    <header className="h-16 border-b border-slate-200 bg-white px-8 flex items-center justify-between select-none">
      {/* Left Title */}
      <div className="flex items-center gap-3">
        <h2 className="text-sm font-bold text-slate-800 tracking-tight">Admin Console Dashboard</h2>
        <span className="text-slate-300">•</span>
        <div className="flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-emerald-50 text-emerald-700 text-xs font-medium border border-emerald-200">
          <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
          <span>Mobile App Live Sync</span>
        </div>
      </div>

      {/* Right Controls */}
      <div className="flex items-center gap-3">
        <button
          onClick={onRefresh}
          disabled={isRefreshing}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-slate-200 hover:bg-slate-50 text-slate-600 hover:text-slate-900 text-xs font-medium transition shadow-xs"
          title="Refresh Data"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${isRefreshing ? 'animate-spin text-slate-900' : ''}`} />
          <span>Refresh</span>
        </button>
      </div>
    </header>
  );
}
