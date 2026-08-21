import React from 'react';
import {
  LayoutDashboard,
  UploadCloud,
  Music,
  UserCheck,
  Users,
  RefreshCw,
} from 'lucide-react';

export default function Sidebar({ activeTab, setActiveTab, metrics }) {
  const navItems = [
    { id: 'overview', label: 'Dashboard', icon: LayoutDashboard },
    { id: 'ingest', label: 'Upload Music', icon: UploadCloud },
    { id: 'catalog', label: 'Song Catalog', icon: Music, count: metrics?.songs || 0 },
    { id: 'artists', label: 'Artists', icon: UserCheck, count: metrics?.artists || 0 },
    { id: 'users', label: 'User Management', icon: Users },
    { id: 'sync', label: 'App Sync', icon: RefreshCw },
  ];

  return (
    <aside className="w-64 bg-white border-r border-slate-200 flex flex-col justify-between select-none">
      <div>
        {/* Brand with App Icon */}
        <div className="h-16 flex items-center px-6 border-b border-slate-100 gap-3">
          <div className="w-9 h-9 rounded-xl overflow-hidden bg-slate-900 flex items-center justify-center shadow-xs shrink-0 border border-slate-200">
            <img
              src="/app_logo.png"
              alt="Muxiz Logo"
              className="w-full h-full object-cover"
              onError={(e) => {
                e.target.style.display = 'none';
              }}
            />
          </div>
          <div>
            <span className="font-bold text-sm tracking-tight text-slate-900 block leading-tight">Muxiz Studio</span>
            <div className="text-[10px] font-semibold text-slate-400 uppercase tracking-wider">Admin Console</div>
          </div>
        </div>

        {/* Navigation */}
        <nav className="p-3 space-y-1">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = activeTab === item.id;
            return (
              <button
                key={item.id}
                onClick={() => setActiveTab(item.id)}
                className={`w-full flex items-center justify-between px-3.5 py-2.5 rounded-lg text-xs font-medium transition-all ${
                  isActive
                    ? 'bg-slate-900 text-white font-semibold shadow-xs'
                    : 'text-slate-600 hover:text-slate-900 hover:bg-slate-50'
                }`}
              >
                <div className="flex items-center gap-2.5">
                  <Icon className={`w-4 h-4 ${isActive ? 'text-white' : 'text-slate-400'}`} />
                  <span>{item.label}</span>
                </div>
                {item.count !== undefined && (
                  <span
                    className={`text-[11px] font-mono px-2 py-0.5 rounded-full ${
                      isActive ? 'bg-slate-800 text-slate-200' : 'bg-slate-100 text-slate-600'
                    }`}
                  >
                    {item.count}
                  </span>
                )}
              </button>
            );
          })}
        </nav>
      </div>

      {/* Clean Footer Status */}
      <div className="p-4 border-t border-slate-100">
        <div className="flex items-center justify-between px-2 text-xs text-slate-500">
          <span className="flex items-center gap-1.5">
            <span className="w-2 h-2 rounded-full bg-emerald-500" />
            System Live
          </span>
          <span className="text-[11px] font-mono text-slate-400">Admin v2.0</span>
        </div>
      </div>
    </aside>
  );
}
