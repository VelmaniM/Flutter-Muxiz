import React, { useState, useEffect } from 'react';
import Sidebar from './components/Sidebar';
import Header from './components/Header';
import OverviewView from './components/OverviewView';
import IngestView from './components/IngestView';
import CatalogView from './components/CatalogView';
import ArtistsView from './components/ArtistsView';
import UsersView from './components/UsersView';
import CacheSyncView from './components/CacheSyncView';
import AudioPlayerBar from './components/AudioPlayerBar';
import { api } from './services/api';

export default function App() {
  const [activeTab, setActiveTab] = useState('overview');
  const [metrics, setMetrics] = useState(null);
  const [isRefreshing, setIsRefreshing] = useState(false);

  // Global Audio Player State
  const [currentSong, setCurrentSong] = useState(null);
  const [isPlaying, setIsPlaying] = useState(false);

  const fetchMetrics = async () => {
    try {
      setIsRefreshing(true);
      const res = await api.getMetrics();
      if (res.success && res.metrics) {
        setMetrics(res.metrics);
      }
    } catch (err) {
      console.warn('Metrics fetch error:', err);
    } finally {
      setIsRefreshing(false);
    }
  };

  useEffect(() => {
    fetchMetrics();
    const timer = setInterval(fetchMetrics, 15000);
    return () => clearInterval(timer);
  }, []);

  const handlePlaySong = (song) => {
    if (currentSong && (currentSong.id === song.id || currentSong._id === song._id)) {
      setIsPlaying(!isPlaying);
    } else {
      setCurrentSong(song);
      setIsPlaying(true);
    }
  };

  return (
    <div className="flex h-screen bg-[#f8fafc] text-slate-900 overflow-hidden font-sans">
      {/* Sidebar Navigation */}
      <Sidebar activeTab={activeTab} setActiveTab={setActiveTab} metrics={metrics} />

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        {/* Header Telemetry Bar */}
        <Header
          metrics={metrics}
          onRefresh={fetchMetrics}
          isRefreshing={isRefreshing}
        />

        {/* View Switcher */}
        <main className="flex-1 overflow-y-auto pb-24 bg-[#f8fafc]">
          {activeTab === 'overview' && (
            <OverviewView
              metrics={metrics}
              setActiveTab={setActiveTab}
              onWipeCache={fetchMetrics}
              currentSong={currentSong}
              isPlaying={isPlaying}
              onPlaySong={handlePlaySong}
            />
          )}

          {activeTab === 'ingest' && (
            <IngestView
              onIngestSuccess={fetchMetrics}
            />
          )}

          {activeTab === 'catalog' && (
            <CatalogView
              currentSong={currentSong}
              isPlaying={isPlaying}
              onPlaySong={handlePlaySong}
              onCatalogChanged={fetchMetrics}
              setActiveTab={setActiveTab}
            />
          )}

          {activeTab === 'artists' && (
            <ArtistsView
              onArtistChanged={fetchMetrics}
            />
          )}

          {activeTab === 'users' && (
            <UsersView />
          )}

          {activeTab === 'sync' && (
            <CacheSyncView
              onEpochBumped={fetchMetrics}
            />
          )}
        </main>

        {/* Bottom Audio Player Bar */}
        <AudioPlayerBar
          song={currentSong}
          isPlaying={isPlaying}
          onTogglePlay={() => setIsPlaying(!isPlaying)}
          onClose={() => {
            setCurrentSong(null);
            setIsPlaying(false);
          }}
        />
      </div>
    </div>
  );
}
