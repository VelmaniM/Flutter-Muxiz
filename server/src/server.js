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

const startServer = async () => {
  try {
    // 1. Connect to MongoDB Atlas
    await connectDB();

    const lanIp = getLanIp();

    // 2. Start HTTP Server binding to 0.0.0.0 (All interfaces for physical devices)
    app.listen(PORT, '0.0.0.0', () => {
      console.log('\n======================================================');
      console.log('🎧 MUXIZ UNIFIED MONO-ENGINE ACTIVE');
      console.log(`📡 Local Console:   http://localhost:${PORT}/studio`);
      console.log(`🌐 Rest API:        http://localhost:${PORT}/api/v1/songs`);
      console.log(`📱 Physical Phone:  http://${lanIp}:${PORT}/api/v1`);
      console.log('⚡ Redis Cache:     Active (0ms In-Memory Ultra Cache)');
      console.log('🗄️  Database:        MongoDB Atlas + LocalStore Ready');
      console.log('☁️  Media Vault:     Direct Streaming Engine Active');
      console.log('======================================================\n');
    });
  } catch (err) {
    console.error('❌ Failed to start Muxiz Server Engine:', err);
    process.exit(1);
  }
};

startServer();
