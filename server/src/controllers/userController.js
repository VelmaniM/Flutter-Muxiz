const User = require('../models/User');
const LocalStore = require('../models/store');
const mongoose = require('mongoose');

class UserController {
  /**
   * GET /api/v1/users
   */
  static async getAllUsers(req, res, next) {
    try {
      const { search, role, status } = req.query;
      let users = [];

      if (mongoose.connection.readyState === 1) {
        const filter = {};
        if (role && role !== 'ALL') filter.role = role;
        if (status && status !== 'ALL') filter.status = status;
        if (search) {
          filter.$or = [
            { name: { $regex: search, $options: 'i' } },
            { email: { $regex: search, $options: 'i' } },
          ];
        }

        users = await User.find(filter).sort({ lastActiveAt: -1, createdAt: -1 }).lean();
      } else {
        // Read strictly from real local users store (NO fake dummy users!)
        users = LocalStore.getLocalUsers();
        if (role && role !== 'ALL') {
          users = users.filter((u) => u.role === role);
        }
        if (status && status !== 'ALL') {
          users = users.filter((u) => u.status === status);
        }
        if (search) {
          const sLower = search.toLowerCase();
          users = users.filter(
            (u) =>
              (u.name && u.name.toLowerCase().includes(sLower)) ||
              (u.email && u.email.toLowerCase().includes(sLower))
          );
        }
      }

      res.json({
        success: true,
        count: users.length,
        users,
        data: users,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/users (and /api/users)
   * Registered / Synced strictly from Front-End Mobile App
   */
  static async createUser(req, res, next) {
    try {
      const { name, email, role, avatarUrl, favoritesCount } = req.body;
      if (!name || !email) {
        return res.status(400).json({ success: false, message: 'Name and email are required.' });
      }

      const emailClean = email.trim().toLowerCase();
      const nameClean = name.trim();

      let user;
      if (mongoose.connection.readyState === 1) {
        // Upsert user from frontend
        user = await User.findOneAndUpdate(
          { email: emailClean },
          {
            name: nameClean,
            ...(avatarUrl && { avatarUrl }),
            ...(favoritesCount !== undefined && { favoritesCount }),
            lastActiveAt: new Date(),
          },
          { upsert: true, new: true, setDefaultsOnInsert: true }
        );
      } else {
        const users = LocalStore.getLocalUsers();
        const existingIdx = users.findIndex((u) => u.email.toLowerCase() === emailClean);
        if (existingIdx !== -1) {
          users[existingIdx] = {
            ...users[existingIdx],
            name: nameClean,
            ...(avatarUrl && { avatarUrl }),
            ...(favoritesCount !== undefined && { favoritesCount }),
            lastActiveAt: new Date().toISOString(),
          };
          user = users[existingIdx];
        } else {
          user = {
            _id: Math.random().toString(36).substring(2, 9),
            id: Math.random().toString(36).substring(2, 9),
            name: nameClean,
            email: emailClean,
            role: role || 'LISTENER',
            status: 'ACTIVE',
            favoritesCount: favoritesCount || 0,
            playlistsCount: 0,
            avatarUrl: avatarUrl || '',
            lastActiveAt: new Date().toISOString(),
            createdAt: new Date().toISOString(),
          };
          users.unshift(user);
        }
        LocalStore.saveLocalUsers(users);
      }

      res.status(201).json({
        success: true,
        message: `Front-end user "${nameClean}" synced successfully.`,
        user,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * PUT /api/v1/users/:id
   * Update User details (Role, Status, Name, Email) from Admin Console
   */
  static async updateUser(req, res, next) {
    try {
      const { name, email, role, status, avatarUrl } = req.body;
      let updated = null;

      if (mongoose.connection.readyState === 1) {
        updated = await User.findByIdAndUpdate(
          req.params.id,
          {
            ...(name && { name: name.trim() }),
            ...(email && { email: email.trim().toLowerCase() }),
            ...(role && { role }),
            ...(status && { status }),
            ...(avatarUrl !== undefined && { avatarUrl }),
          },
          { new: true }
        );
      } else {
        const users = LocalStore.getLocalUsers();
        const idx = users.findIndex((u) => (u._id || u.id) === req.params.id);
        if (idx !== -1) {
          users[idx] = {
            ...users[idx],
            ...(name && { name: name.trim() }),
            ...(email && { email: email.trim().toLowerCase() }),
            ...(role && { role }),
            ...(status && { status }),
            ...(avatarUrl !== undefined && { avatarUrl }),
          };
          LocalStore.saveLocalUsers(users);
          updated = users[idx];
        }
      }

      if (!updated) {
        return res.status(404).json({ success: false, message: 'User not found.' });
      }

      res.json({
        success: true,
        message: 'User details updated successfully.',
        user: updated,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * DELETE /api/v1/users/:id
   */
  static async deleteUser(req, res, next) {
    try {
      if (mongoose.connection.readyState === 1) {
        await User.findByIdAndDelete(req.params.id);
      } else {
        const users = LocalStore.getLocalUsers();
        const filtered = users.filter((u) => (u._id || u.id) !== req.params.id);
        LocalStore.saveLocalUsers(filtered);
      }

      res.json({
        success: true,
        message: 'User account removed successfully.',
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = UserController;
