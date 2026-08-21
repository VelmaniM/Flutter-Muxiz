import React, { useState, useEffect } from 'react';
import { Search, UserCheck, Shield, User, Trash2, Edit2, X, RefreshCw, Smartphone, CheckCircle2, AlertCircle } from 'lucide-react';
import { api } from '../services/api';

export default function UsersView({ onUserChanged }) {
  const [users, setUsers] = useState([]);
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState('ALL');
  const [isLoading, setIsLoading] = useState(true);
  const [editingUser, setEditingUser] = useState(null);

  const fetchUsers = async () => {
    try {
      setIsLoading(true);
      const res = await api.getUsers({ search, role: roleFilter });
      if (res.success) {
        setUsers(res.users || []);
      }
    } catch (err) {
      console.error('Fetch users error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, [search, roleFilter]);

  const handleSaveEdit = async (e) => {
    e.preventDefault();
    if (!editingUser) return;
    try {
      const id = editingUser.id || editingUser._id;
      const res = await api.updateUser(id, editingUser);
      if (res.success) {
        setUsers((prev) =>
          prev.map((u) => ((u.id || u._id) === id ? res.user : u))
        );
        setEditingUser(null);
        if (onUserChanged) onUserChanged();
      }
    } catch (err) {
      alert('Failed to update user: ' + err.message);
    }
  };

  const handleToggleStatus = async (user) => {
    const nextStatus = user.status === 'ACTIVE' ? 'SUSPENDED' : 'ACTIVE';
    try {
      const res = await api.updateUser(user.id || user._id, { status: nextStatus });
      if (res.success) {
        setUsers((prev) =>
          prev.map((u) => ((u.id || u._id) === (user.id || user._id) ? { ...u, status: nextStatus } : u))
        );
        if (onUserChanged) onUserChanged();
      }
    } catch (err) {
      alert('Failed to update user status: ' + err.message);
    }
  };

  const handleDeleteUser = async (id, name) => {
    if (!window.confirm(`Are you sure you want to delete user account "${name}"?`)) return;
    try {
      const res = await api.deleteUser(id);
      if (res.success) {
        setUsers((prev) => prev.filter((u) => (u.id || u._id) !== id));
        if (onUserChanged) onUserChanged();
      }
    } catch (err) {
      alert('Failed to delete user: ' + err.message);
    }
  };

  return (
    <div className="p-8 space-y-6 max-w-6xl mx-auto">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-slate-900 tracking-tight">User Management</h1>
          <p className="text-xs text-slate-500 mt-0.5">
            {users.length} mobile app listeners registered from frontend
          </p>
        </div>

        <div className="flex items-center gap-3">
          <div className="relative w-64">
            <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Search user name, email..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full bg-white border border-slate-200 rounded-lg pl-9 pr-3 py-1.5 text-xs text-slate-900 placeholder-slate-400 focus:outline-none focus:border-slate-400 font-medium shadow-xs"
            />
          </div>

          <button
            onClick={fetchUsers}
            className="p-2 bg-white hover:bg-slate-50 border border-slate-200 rounded-lg text-slate-600 hover:text-slate-900 transition shadow-xs"
            title="Refresh List"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isLoading ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {/* Users Table */}
      <div className="rounded-2xl border border-slate-200 bg-white overflow-hidden shadow-xs">
        <table className="w-full text-left text-xs">
          <thead className="bg-slate-50/75 border-b border-slate-100 text-[11px] font-semibold text-slate-500 select-none">
            <tr>
              <th className="py-3 px-4">User</th>
              <th className="py-3 px-4">Email</th>
              <th className="py-3 px-4">Role</th>
              <th className="py-3 px-4">Favorites</th>
              <th className="py-3 px-4">Status</th>
              <th className="py-3 px-4 text-right">Actions</th>
            </tr>
          </thead>

          <tbody className="divide-y divide-slate-100 text-slate-700">
            {users.length === 0 ? (
              <tr>
                <td colSpan="6" className="py-14 text-center text-slate-400 text-xs">
                  {isLoading ? (
                    'Loading mobile app accounts...'
                  ) : (
                    <div className="space-y-1">
                      <div className="w-10 h-10 rounded-full bg-slate-100 text-slate-400 mx-auto flex items-center justify-center mb-2">
                        <Smartphone className="w-5 h-5" />
                      </div>
                      <p className="font-semibold text-slate-700">No frontend users registered yet.</p>
                      <p className="text-[11px] text-slate-400">
                        When users launch and listen to songs on the Flutter mobile app, their accounts will appear here automatically.
                      </p>
                    </div>
                  )}
                </td>
              </tr>
            ) : (
              users.map((user) => {
                const userId = user.id || user._id;
                const isSuspended = user.status === 'SUSPENDED';
                return (
                  <tr key={userId} className="hover:bg-slate-50/80 transition">
                    <td className="py-3 px-4">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-full bg-slate-900 text-white flex items-center justify-center font-bold text-xs shrink-0">
                          {user.name ? user.name[0].toUpperCase() : 'U'}
                        </div>
                        <div className="font-semibold text-slate-900">{user.name}</div>
                      </div>
                    </td>

                    <td className="py-3 px-4 text-slate-500 font-mono text-[11px]">{user.email}</td>

                    <td className="py-3 px-4">
                      <span
                        className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                          user.role === 'ADMIN'
                            ? 'bg-purple-100 text-purple-800'
                            : user.role === 'VIP'
                            ? 'bg-amber-100 text-amber-800'
                            : 'bg-slate-100 text-slate-700'
                        }`}
                      >
                        {user.role || 'LISTENER'}
                      </span>
                    </td>

                    <td className="py-3 px-4 text-slate-600 font-medium">{user.favoritesCount || 0} Songs</td>

                    <td className="py-3 px-4">
                      <span
                        className={`inline-flex items-center gap-1 text-[11px] font-medium ${
                          !isSuspended ? 'text-emerald-700' : 'text-rose-600'
                        }`}
                      >
                        <span
                          className={`w-1.5 h-1.5 rounded-full ${
                            !isSuspended ? 'bg-emerald-500' : 'bg-rose-500'
                          }`}
                        />
                        <span>{user.status || 'ACTIVE'}</span>
                      </span>
                    </td>

                    <td className="py-3 px-4 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        <button
                          onClick={() => setEditingUser(user)}
                          className="p-1.5 rounded-lg hover:bg-slate-100 text-slate-400 hover:text-slate-700 transition"
                          title="Edit User"
                        >
                          <Edit2 className="w-3.5 h-3.5" />
                        </button>
                        <button
                          onClick={() => handleToggleStatus(user)}
                          className={`px-2.5 py-1 rounded-lg border text-[11px] font-medium transition ${
                            !isSuspended
                              ? 'border-slate-200 hover:bg-slate-50 text-slate-600'
                              : 'border-emerald-200 bg-emerald-50 hover:bg-emerald-100 text-emerald-700'
                          }`}
                        >
                          {!isSuspended ? 'Suspend' : 'Activate'}
                        </button>
                        <button
                          onClick={() => handleDeleteUser(userId, user.name)}
                          className="p-1.5 rounded-lg hover:bg-rose-50 text-slate-400 hover:text-rose-600 transition"
                          title="Delete User"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {/* Edit User Modal */}
      {editingUser && (
        <div className="fixed inset-0 bg-slate-900/30 backdrop-blur-xs flex items-center justify-center p-4 z-50">
          <div className="bg-white border border-slate-200 rounded-2xl p-6 w-full max-w-md space-y-4 shadow-xl">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <h2 className="text-sm font-bold text-slate-900">Edit User Details</h2>
              <button onClick={() => setEditingUser(null)} className="text-slate-400 hover:text-slate-600">
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleSaveEdit} className="space-y-3.5">
              <div>
                <label className="text-[11px] text-slate-500 font-medium block mb-1">Full Name</label>
                <input
                  type="text"
                  value={editingUser.name || ''}
                  onChange={(e) => setEditingUser({ ...editingUser, name: e.target.value })}
                  className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-2 text-xs text-slate-900 focus:bg-white focus:outline-none focus:border-slate-400 font-medium"
                />
              </div>

              <div>
                <label className="text-[11px] text-slate-500 font-medium block mb-1">Email Address</label>
                <input
                  type="email"
                  value={editingUser.email || ''}
                  onChange={(e) => setEditingUser({ ...editingUser, email: e.target.value })}
                  className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-2 text-xs text-slate-900 focus:bg-white focus:outline-none focus:border-slate-400"
                />
              </div>

              <div>
                <label className="text-[11px] text-slate-500 font-medium block mb-1">Account Role</label>
                <select
                  value={editingUser.role || 'LISTENER'}
                  onChange={(e) => setEditingUser({ ...editingUser, role: e.target.value })}
                  className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-2 text-xs text-slate-900 focus:bg-white focus:outline-none focus:border-slate-400"
                >
                  <option value="LISTENER">Listener (Free)</option>
                  <option value="VIP">VIP Subscriber</option>
                  <option value="CREATOR">Artist / Creator</option>
                  <option value="ADMIN">Studio Admin</option>
                </select>
              </div>

              <div>
                <label className="text-[11px] text-slate-500 font-medium block mb-1">Account Status</label>
                <select
                  value={editingUser.status || 'ACTIVE'}
                  onChange={(e) => setEditingUser({ ...editingUser, status: e.target.value })}
                  className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-2 text-xs text-slate-900 focus:bg-white focus:outline-none focus:border-slate-400"
                >
                  <option value="ACTIVE">ACTIVE</option>
                  <option value="SUSPENDED">SUSPENDED</option>
                </select>
              </div>

              <div className="flex justify-end gap-2.5 pt-3">
                <button
                  type="button"
                  onClick={() => setEditingUser(null)}
                  className="px-4 py-2 rounded-lg border border-slate-200 hover:bg-slate-50 text-slate-600 text-xs font-medium transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-lg bg-slate-900 hover:bg-slate-800 text-white text-xs font-semibold transition shadow-xs"
                >
                  Save Changes
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
