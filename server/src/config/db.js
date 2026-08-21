const mongoose = require('mongoose');

let isConnected = false;

const connectDB = async () => {
  if (isConnected) {
    return;
  }

  const mongoUri = process.env.MONGODB_URI;
  if (!mongoUri) {
    console.warn('⚠️ [DB Warning] MONGODB_URI is not set. Running in memory fallback mode.');
    return;
  }

  try {
    const db = await mongoose.connect(mongoUri, {
      serverSelectionTimeoutMS: 5000,
      socketTimeoutMS: 45000,
    });

    isConnected = db.connections[0].readyState === 1;
    console.log(`🗄️  [MongoDB Atlas] Connected successfully to host: ${db.connection.host}`);
  } catch (error) {
    console.error('❌ [MongoDB Atlas Error]', error.message);
    // Don't crash process, allow server to boot and serve fallback/cache
  }
};

module.exports = { connectDB, isConnected: () => isConnected };
