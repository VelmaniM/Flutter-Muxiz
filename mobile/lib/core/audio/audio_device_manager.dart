import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DeviceAudioType {
  speaker,
  bluetooth,
  headphones,
  airplay,
  other,
}

class ConnectedAudioDevice {
  final String id;
  final String name;
  final DeviceAudioType type;
  final IconData icon;
  final bool isCurrent;

  const ConnectedAudioDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    this.isCurrent = false,
  });
}

final audioDeviceProvider = StateNotifierProvider<AudioDeviceNotifier, ConnectedAudioDevice>((ref) {
  return AudioDeviceNotifier();
});

class AudioDeviceNotifier extends StateNotifier<ConnectedAudioDevice> {
  StreamSubscription? _sub;

  AudioDeviceNotifier()
      : super(const ConnectedAudioDevice(
          id: 'built_in_speaker',
          name: 'iPhone Speaker',
          type: DeviceAudioType.speaker,
          icon: Icons.phone_iphone_rounded,
          isCurrent: true,
        )) {
    _initDeviceListener();
  }

  Future<void> _initDeviceListener() async {
    try {
      final session = await AudioSession.instance;
      _updateDevices(await session.getDevices());

      _sub = session.devicesStream.listen((devices) {
        _updateDevices(devices);
      });
    } catch (_) {
      // Default to iPhone Speaker
    }
  }

  void _updateDevices(Set<AudioDevice> devices) {
    AudioDevice? activeOutput;
    for (final d in devices) {
      if (d.isOutput) {
        final typeName = d.type.name.toLowerCase();
        if (typeName.contains('bluetooth') ||
            typeName.contains('a2dp') ||
            typeName.contains('headphone') ||
            typeName.contains('headset') ||
            typeName.contains('airplay')) {
          activeOutput = d;
          break;
        }
        activeOutput ??= d;
      }
    }

    if (activeOutput != null) {
      final typeName = activeOutput.type.name.toLowerCase();
      if (typeName.contains('bluetooth') || typeName.contains('a2dp') || typeName.contains('ble')) {
        state = ConnectedAudioDevice(
          id: activeOutput.id,
          name: activeOutput.name.isNotEmpty ? activeOutput.name : 'Bluetooth Audio / AirPods',
          type: DeviceAudioType.bluetooth,
          icon: Icons.headphones_rounded,
          isCurrent: true,
        );
      } else if (typeName.contains('headphone') || typeName.contains('headset') || typeName.contains('wired')) {
        state = ConnectedAudioDevice(
          id: activeOutput.id,
          name: activeOutput.name.isNotEmpty ? activeOutput.name : 'Wired Headphones',
          type: DeviceAudioType.headphones,
          icon: Icons.headphones_rounded,
          isCurrent: true,
        );
      } else if (typeName.contains('airplay')) {
        state = ConnectedAudioDevice(
          id: activeOutput.id,
          name: activeOutput.name.isNotEmpty ? activeOutput.name : 'AirPlay Speaker',
          type: DeviceAudioType.airplay,
          icon: Icons.airplay_rounded,
          isCurrent: true,
        );
      } else {
        state = ConnectedAudioDevice(
          id: activeOutput.id,
          name: 'iPhone Speaker',
          type: DeviceAudioType.speaker,
          icon: Icons.phone_iphone_rounded,
          isCurrent: true,
        );
      }
    }
  }

  Future<void> switchAudioOutput(DeviceAudioType targetType) async {
    try {
      final session = await AudioSession.instance;
      if (Platform.isIOS) {
        final darwin = AVAudioSession();
        if (targetType == DeviceAudioType.speaker) {
          await darwin.overrideOutputAudioPort(AVAudioSessionPortOverride.speaker);
          state = const ConnectedAudioDevice(
            id: 'built_in_speaker',
            name: 'iPhone Speaker',
            type: DeviceAudioType.speaker,
            icon: Icons.phone_iphone_rounded,
            isCurrent: true,
          );
        } else {
          await darwin.overrideOutputAudioPort(AVAudioSessionPortOverride.none);
          final devices = await session.getDevices();
          _updateDevices(devices);
        }
      } else if (Platform.isAndroid) {
        final android = AndroidAudioManager();
        if (targetType == DeviceAudioType.speaker) {
          await android.setSpeakerphoneOn(true);
          state = const ConnectedAudioDevice(
            id: 'built_in_speaker',
            name: 'Phone Speaker',
            type: DeviceAudioType.speaker,
            icon: Icons.phone_iphone_rounded,
            isCurrent: true,
          );
        } else {
          await android.setSpeakerphoneOn(false);
          final devices = await session.getDevices();
          _updateDevices(devices);
        }
      }
    } catch (e) {
      debugPrint('Error switching audio output: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class BluetoothDeviceItem {
  final String id;
  final String name;
  final int rssi;
  final BluetoothDevice device;
  final bool isConnected;

  const BluetoothDeviceItem({
    required this.id,
    required this.name,
    required this.rssi,
    required this.device,
    this.isConnected = false,
  });
}

class BluetoothManagerState {
  final BluetoothAdapterState adapterState;
  final bool isScanning;
  final List<BluetoothDeviceItem> discoveredDevices;
  final String? connectingDeviceId;
  final String? errorMessage;

  const BluetoothManagerState({
    this.adapterState = BluetoothAdapterState.unknown,
    this.isScanning = false,
    this.discoveredDevices = const [],
    this.connectingDeviceId,
    this.errorMessage,
  });

  BluetoothManagerState copyWith({
    BluetoothAdapterState? adapterState,
    bool? isScanning,
    List<BluetoothDeviceItem>? discoveredDevices,
    String? connectingDeviceId,
    String? errorMessage,
  }) {
    return BluetoothManagerState(
      adapterState: adapterState ?? this.adapterState,
      isScanning: isScanning ?? this.isScanning,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      connectingDeviceId: connectingDeviceId,
      errorMessage: errorMessage,
    );
  }
}

final bluetoothManagerProvider =
    StateNotifierProvider<BluetoothManagerNotifier, BluetoothManagerState>((ref) {
  return BluetoothManagerNotifier();
});

class BluetoothManagerNotifier extends StateNotifier<BluetoothManagerState> {
  StreamSubscription? _adapterStateSub;
  StreamSubscription? _scanResultsSub;
  StreamSubscription? _isScanningSub;

  BluetoothManagerNotifier() : super(const BluetoothManagerState()) {
    _initBluetoothListeners();
  }

  void _initBluetoothListeners() {
    try {
      _adapterStateSub = FlutterBluePlus.adapterState.listen((stateEvent) {
        state = state.copyWith(adapterState: stateEvent);
      });

      _isScanningSub = FlutterBluePlus.isScanning.listen((scanning) {
        state = state.copyWith(isScanning: scanning);
      });

      _scanResultsSub = FlutterBluePlus.scanResults.listen((results) {
        final List<BluetoothDeviceItem> items = [];
        final Set<String> seenIds = {};

        for (final r in results) {
          final dev = r.device;
          final name = dev.platformName.isNotEmpty
              ? dev.platformName
              : (dev.advName.isNotEmpty ? dev.advName : '');

          if (name.isNotEmpty && !seenIds.contains(dev.remoteId.str)) {
            seenIds.add(dev.remoteId.str);
            items.add(
              BluetoothDeviceItem(
                id: dev.remoteId.str,
                name: name,
                rssi: r.rssi,
                device: dev,
                isConnected: dev.isConnected,
              ),
            );
          }
        }

        // Sort by signal strength
        items.sort((a, b) => b.rssi.compareTo(a.rssi));
        state = state.copyWith(discoveredDevices: items);
      });
    } catch (_) {}
  }

  Future<void> startScan() async {
    try {
      state = state.copyWith(errorMessage: null);
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8),
        androidUsesFineLocation: false,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Bluetooth scan error: $e');
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  Future<bool> connectDevice(BluetoothDeviceItem item) async {
    try {
      state = state.copyWith(connectingDeviceId: item.id, errorMessage: null);
      await FlutterBluePlus.stopScan();
      await item.device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 6),
        autoConnect: false,
      );
      state = state.copyWith(connectingDeviceId: null);
      return true;
    } catch (e) {
      state = state.copyWith(connectingDeviceId: null, errorMessage: 'Failed to connect: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _adapterStateSub?.cancel();
    _scanResultsSub?.cancel();
    _isScanningSub?.cancel();
    super.dispose();
  }
}

