require('dotenv').config();
const app = require('./app');
const { connectDB } = require('./config/db');
const os = require('os');

const PORT = process.env.PORT || 5001;

// Discover Local Network LAN IP for Physical Phones (Android / iOS)
const getLanIp = () => {
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        return iface.address;
      }
    }
  }
  return 'localhost';
};

const startServer = () => {
  try {
    const lanIp = getLanIp();

    // 1. Start HTTP Server immediately binding to 0.0.0.0 for instant Render health check
    const server = app.listen(PORT, '0.0.0.0', () => {
      console.log('\n======================================================');
      console.log('🎧 MUXIZ UNIFIED MONO-ENGINE ACTIVE');
      console.log(`📡 Local Console:   http://localhost:${PORT}/studio`);
      console.log(`🌐 Rest API:        http://localhost:${PORT}/api/v1/songs`);
      console.log(`📱 Physical Phone:  http://${lanIp}:${PORT}/api/v1`);
      console.log('⚡ Redis Cache:     Active (0ms In-Memory Ultra Cache)');
      console.log('🗄️  Database:        Connecting to MongoDB Atlas in background...');
      console.log('☁️  Media Vault:     Direct Streaming Engine Active');
      console.log('======================================================\n');

      // 2. Connect to MongoDB Atlas concurrently
      connectDB().catch((err) => {
        console.warn('⚠️ [MongoDB Startup Notice]', err.message);
      });
    });

    server.on('error', (err) => {
      console.error('❌ Server listen error:', err);
      process.exit(1);
    });
  } catch (err) {
    console.error('❌ Failed to start Muxiz Server Engine:', err);
    process.exit(1);
  }
};

startServer();
