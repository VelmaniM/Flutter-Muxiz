'use client';

import React from 'react';
import { UploadCloud, Music, Users, Activity, RefreshCw, Power } from 'lucide-react';

export default function Sidebar({
  activeTab,
  setActiveTab,
  totalSongs,
  totalArtists,
  dbStatus,
  serverActive,
  onToggleServerPower,
  onRefresh,
  isRefreshing,
}) {
  const navItems = [
    { id: 'queue', label: 'Ingest Queue', icon: UploadCloud },
    { id: 'catalog', label: 'Music Catalog', icon: Music, badge: totalSongs },
    { id: 'artists', label: 'Artists Directory', icon: Users, badge: totalArtists },
    { id: 'health', label: 'Database & Cloud', icon: Activity },
  ];

  return (
    <aside className="sidebar">
      {/* Brand Header */}
      <div style={{ padding: '18px 20px', borderBottom: '1px solid var(--border-main)' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <img
              src="/app_logo.png"
              alt="Muxiz Logo"
              style={{ width: '28px', height: '28px', borderRadius: '7px' }}
              onError={(e) => {
                e.target.style.display = 'none';
              }}
            />
            <div>
              <h1 style={{ fontSize: '15px', fontWeight: 800, letterSpacing: '-0.02em', lineHeight: 1.2 }}>
                MUXIZ STUDIO
              </h1>
              <p style={{ fontSize: '11px', color: 'var(--text-muted)', fontWeight: 500 }}>
                Next.js Ingestion Engine
              </p>
            </div>
          </div>

          <button
            onClick={onRefresh}
            className="play-icon-btn"
            title="Refresh Catalog Data"
            style={{ padding: '6px' }}
          >
            <RefreshCw size={14} className={isRefreshing ? 'animate-spin' : ''} />
          </button>
        </div>

        {/* Server Power Switch Box in Sidebar */}
        <div
          style={{
            marginTop: '14px',
            padding: '10px 12px',
            background: '#F9FAFB',
            border: '1px solid var(--border-main)',
            borderRadius: '8px',
            display: 'flex',
            flexDirection: 'column',
            gap: '6px',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <span style={{ fontSize: '11.5px', fontWeight: 700, color: 'var(--text-main)', display: 'flex', alignItems: 'center', gap: '6px' }}>
              <Power size={13} color={serverActive ? '#10B981' : '#EF4444'} />
              Studio Server
            </span>
            <button
              onClick={onToggleServerPower}
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '5px',
                padding: '3px 8px',
                borderRadius: '16px',
                fontSize: '11px',
                fontWeight: 700,
                cursor: 'pointer',
                border: '1px solid',
                background: serverActive ? '#ECFDF5' : '#FEF2F2',
                borderColor: serverActive ? '#A7F3D0' : '#FECACA',
                color: serverActive ? '#059669' : '#DC2626',
                transition: 'all 0.15s ease',
              }}
              title="Click to toggle Server ON / OFF"
            >
              <span
                style={{
                  width: '6px',
                  height: '6px',
                  borderRadius: '50%',
                  background: serverActive ? '#10B981' : '#EF4444',
                }}
              />
              {serverActive ? 'ON' : 'OFF'}
            </button>
          </div>
          <span style={{ fontSize: '10px', color: 'var(--text-muted)' }}>
            {serverActive ? '🟢 Live streaming to Mobile App' : '🔴 App in Skeleton Shimmer mode'}
          </span>
        </div>
      </div>

      {/* Navigation Links */}
      <nav style={{ flex: 1, padding: '12px 10px', display: 'flex', flexDirection: 'column', gap: '4px' }}>
        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = activeTab === item.id;

          return (
            <button
              key={item.id}
              onClick={() => setActiveTab(item.id)}
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '9px 12px',
                borderRadius: '6px',
                border: 'none',
                background: isActive ? '#111827' : 'transparent',
                color: isActive ? '#FFFFFF' : '#374151',
                fontWeight: isActive ? 600 : 500,
                fontSize: '13px',
                cursor: 'pointer',
                textAlign: 'left',
                transition: 'all 0.15s ease',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <Icon size={16} color={isActive ? '#FFFFFF' : '#6B7280'} />
                <span>{item.label}</span>
              </div>

              {item.badge !== undefined && (
                <span
                  style={{
                    fontSize: '11px',
                    fontWeight: 600,
                    padding: '2px 7px',
                    borderRadius: '10px',
                    background: isActive ? 'rgba(255,255,255,0.2)' : 'var(--bg-subtle)',
                    color: isActive ? '#FFFFFF' : '#6B7280',
                  }}
                >
                  {item.badge}
                </span>
              )}
            </button>
          );
        })}
      </nav>

      {/* Status Footer */}
      <div style={{ padding: '16px 20px', borderTop: '1px solid var(--border-main)', background: '#FAFAFA' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '6px' }}>
          <span style={{ fontSize: '11px', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase' }}>
            Database
          </span>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <div
              style={{
                width: '7px',
                height: '7px',
                borderRadius: '50%',
                background: dbStatus === 'connected' ? 'var(--emerald)' : 'var(--red)',
              }}
            />
            <span style={{ fontSize: '11.5px', fontWeight: 600, color: '#374151' }}>
              {dbStatus === 'connected' ? 'PostgreSQL' : 'Connecting...'}
            </span>
          </div>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <span style={{ fontSize: '11px', color: 'var(--text-dim)' }}>Storage Engine</span>
          <span style={{ fontSize: '11.5px', color: 'var(--text-muted)', fontWeight: 500 }}>Google Drive</span>
        </div>
      </div>
    </aside>
  );
}
