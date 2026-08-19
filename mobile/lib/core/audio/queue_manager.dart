import '../../shared/models/song.dart';
import '../data/mock_catalog.dart';
import 'playback_state.dart';

class QueueManager {
  List<Song> _originalQueue = [];
  List<Song> _effectiveQueue = [];
  int _currentIndex = 0;
  bool _isShuffling = false;
  AudioRepeatMode _repeatMode = AudioRepeatMode.off;

  List<Song> get queue => List.unmodifiable(_effectiveQueue);
  int get currentIndex => _currentIndex;
  Song? get currentSong =>
      (_currentIndex >= 0 && _currentIndex < _effectiveQueue.length)
          ? _effectiveQueue[_currentIndex]
          : null;
  bool get isShuffling => _isShuffling;
  AudioRepeatMode get repeatMode => _repeatMode;
  bool get isEmpty => _effectiveQueue.isEmpty;
  int get length => _effectiveQueue.length;

  void setQueue(List<Song> songs, {int initialIndex = 0}) {
    if (songs.isEmpty) {
      _originalQueue = [];
      _effectiveQueue = [];
      _currentIndex = 0;
      return;
    }

    _originalQueue = List<Song>.from(songs);
    _effectiveQueue = List<Song>.from(songs);
    _currentIndex = (initialIndex >= 0 && initialIndex < songs.length) ? initialIndex : 0;

    if (_isShuffling) {
      _applyShuffle();
    }
  }

  /// Builds a smart continuous queue starting with [song]
  void setSmartQueue(Song song, {List<Song>? providedQueue, int? index}) {
    if (providedQueue != null && providedQueue.length > 1) {
      final safeIndex = index ?? providedQueue.indexWhere((s) => s.id == song.id);
      setQueue(providedQueue, initialIndex: safeIndex >= 0 ? safeIndex : 0);
    } else {
      final all = MockMusicCatalog.allSongs;
      final matchIndex = all.indexWhere((s) => s.id == song.id);
      if (matchIndex != -1 && all.length > 1) {
        final smartList = [
          ...all.sublist(matchIndex),
          ...all.sublist(0, matchIndex),
        ];
        setQueue(smartList, initialIndex: 0);
      } else {
        setQueue([song], initialIndex: 0);
      }
    }
  }

  void setCurrentIndex(int index) {
    if (index >= 0 && index < _effectiveQueue.length) {
      _currentIndex = index;
    }
  }

  void addToQueue(Song song) {
    if (_effectiveQueue.isEmpty) {
      setQueue([song], initialIndex: 0);
      return;
    }
    _originalQueue.add(song);
    _effectiveQueue.add(song);
  }

  void playNext(Song song) {
    if (_effectiveQueue.isEmpty) {
      setQueue([song], initialIndex: 0);
      return;
    }

    // If already playing this song, no need to insert
    if (currentSong?.id == song.id) return;

    // Remove any existing duplicate later in the queue
    final existingIdx = _effectiveQueue.indexWhere((s) => s.id == song.id);
    if (existingIdx != -1 && existingIdx != _currentIndex) {
      _effectiveQueue.removeAt(existingIdx);
      _originalQueue.removeWhere((s) => s.id == song.id);
      if (existingIdx < _currentIndex) {
        _currentIndex = (_currentIndex - 1).clamp(0, _effectiveQueue.length - 1);
      }
    }

    final insertIndex = (_currentIndex + 1).clamp(0, _effectiveQueue.length);
    _effectiveQueue.insert(insertIndex, song);
    _originalQueue.insert(insertIndex, song);
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _effectiveQueue.length) return;
    final removedSong = _effectiveQueue.removeAt(index);
    _originalQueue.removeWhere((s) => s.id == removedSong.id);

    if (index < _currentIndex) {
      _currentIndex = (_currentIndex - 1).clamp(0, _effectiveQueue.length - 1);
    } else if (_currentIndex >= _effectiveQueue.length) {
      _currentIndex = (_effectiveQueue.length - 1).clamp(0, _effectiveQueue.length - 1);
    }
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _effectiveQueue.length) return;
    if (newIndex < 0 || newIndex > _effectiveQueue.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _effectiveQueue.removeAt(oldIndex);
    _effectiveQueue.insert(newIndex, item);

    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex -= 1;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex += 1;
    }
  }

  void setShuffle(bool enabled) {
    if (_isShuffling == enabled) return;
    _isShuffling = enabled;
    if (enabled) {
      _applyShuffle();
    } else {
      _restoreOriginalOrder();
    }
  }

  void setRepeatMode(AudioRepeatMode mode) {
    _repeatMode = mode;
  }

  int? getNextIndex() {
    if (_effectiveQueue.isEmpty) return null;

    if (_repeatMode == AudioRepeatMode.one) {
      return _currentIndex;
    }

    final nextIndex = _currentIndex + 1;
    if (nextIndex < _effectiveQueue.length) {
      return nextIndex;
    } else if (_repeatMode == AudioRepeatMode.all) {
      return 0;
    }
    return null;
  }

  int? getPreviousIndex({int positionSeconds = 0}) {
    if (_effectiveQueue.isEmpty) return null;

    if (positionSeconds > 3) {
      return _currentIndex;
    }

    final prevIndex = _currentIndex - 1;
    if (prevIndex >= 0) {
      return prevIndex;
    } else if (_repeatMode == AudioRepeatMode.all) {
      return _effectiveQueue.length - 1;
    }
    return 0;
  }

  void _applyShuffle() {
    if (_effectiveQueue.length <= 1) return;
    final current = currentSong;
    final shuffled = List<Song>.from(_effectiveQueue)..shuffle();
    if (current != null) {
      shuffled.removeWhere((s) => s.id == current.id);
      shuffled.insert(0, current);
    }
    _effectiveQueue = shuffled;
    _currentIndex = 0;
  }

  void _restoreOriginalOrder() {
    final current = currentSong;
    _effectiveQueue = List<Song>.from(_originalQueue);
    if (current != null) {
      final newIdx = _effectiveQueue.indexWhere((s) => s.id == current.id);
      _currentIndex = newIdx >= 0 ? newIdx : 0;
    }
  }
}
