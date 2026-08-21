const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');

const dataDir = path.join(__dirname, '../../data');
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}

const songsFile = path.join(dataDir, 'songs.json');
const epochFile = path.join(dataDir, 'epoch.json');

// Memory/File Store Fallback for 100% Uptime
class LocalStore {
  static getLocalSongs() {
    try {
      if (fs.existsSync(songsFile)) {
        return JSON.parse(fs.readFileSync(songsFile, 'utf8'));
      }
    } catch (_) {}
    return [];
  }

  static saveLocalSongs(songs) {
    try {
      fs.writeFileSync(songsFile, JSON.stringify(songs, null, 2), 'utf8');
    } catch (err) {
      console.warn('Save local songs warning:', err.message);
    }
  }

  static getLocalEpoch() {
    try {
      if (fs.existsSync(epochFile)) {
        return JSON.parse(fs.readFileSync(epochFile, 'utf8'));
      }
    } catch (_) {}
    return { epoch: Date.now(), action: 'SYNC' };
  }

  static saveLocalEpoch(data) {
    try {
      fs.writeFileSync(epochFile, JSON.stringify(data, null, 2), 'utf8');
    } catch (_) {}
  }

  static getLocalUsers() {
    const usersFile = path.join(dataDir, 'users.json');
    try {
      if (fs.existsSync(usersFile)) {
        return JSON.parse(fs.readFileSync(usersFile, 'utf8'));
      }
    } catch (_) {}
    return [];
  }

  static saveLocalUsers(users) {
    const usersFile = path.join(dataDir, 'users.json');
    try {
      fs.writeFileSync(usersFile, JSON.stringify(users, null, 2), 'utf8');
    } catch (_) {}
  }
}

module.exports = LocalStore;
