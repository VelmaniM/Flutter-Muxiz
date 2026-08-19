import 'package:flutter/material.dart';

enum AudioRouteType {
  speaker,
  airpods,
  bluetooth,
  headphones,
  airplay,
  car,
  usb,
  unknown,
}

class AudioRoute {
  final String id;
  final String name;
  final AudioRouteType type;
  final bool isSelected;
  final bool isAvailable;
  final int? batteryLevel;

  const AudioRoute({
    required this.id,
    required this.name,
    required this.type,
    this.isSelected = false,
    this.isAvailable = true,
    this.batteryLevel,
  });

  AudioRoute copyWith({
    String? id,
    String? name,
    AudioRouteType? type,
    bool? isSelected,
    bool? isAvailable,
    int? batteryLevel,
  }) {
    return AudioRoute(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isSelected: isSelected ?? this.isSelected,
      isAvailable: isAvailable ?? this.isAvailable,
      batteryLevel: batteryLevel ?? this.batteryLevel,
    );
  }

  factory AudioRoute.fromMap(Map<dynamic, dynamic> map) {
    final typeStr = map['type']?.toString().toLowerCase() ?? 'unknown';
    final nameStr = map['name']?.toString() ?? 'Audio Output';
    
    AudioRouteType parsedType;
    if (typeStr.contains('speaker') || typeStr.contains('builtin')) {
      parsedType = AudioRouteType.speaker;
    } else if (typeStr.contains('airpod') || nameStr.toLowerCase().contains('airpod')) {
      parsedType = AudioRouteType.airpods;
    } else if (typeStr.contains('bluetooth') || typeStr.contains('a2dp') || typeStr.contains('ble')) {
      parsedType = AudioRouteType.bluetooth;
    } else if (typeStr.contains('headphone') || typeStr.contains('headset') || typeStr.contains('wired')) {
      parsedType = AudioRouteType.headphones;
    } else if (typeStr.contains('airplay')) {
      parsedType = AudioRouteType.airplay;
    } else if (typeStr.contains('car')) {
      parsedType = AudioRouteType.car;
    } else if (typeStr.contains('usb')) {
      parsedType = AudioRouteType.usb;
    } else {
      parsedType = AudioRouteType.unknown;
    }

    return AudioRoute(
      id: map['id']?.toString() ?? 'unknown',
      name: nameStr,
      type: parsedType,
      isSelected: map['isSelected'] == true,
      isAvailable: map['isAvailable'] != false,
      batteryLevel: map['batteryLevel'] is int ? map['batteryLevel'] : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'isSelected': isSelected,
      'isAvailable': isAvailable,
      'batteryLevel': batteryLevel,
    };
  }

  IconData get icon {
    switch (type) {
      case AudioRouteType.speaker:
        return Icons.phone_iphone_rounded;
      case AudioRouteType.airpods:
        return Icons.headphones_rounded;
      case AudioRouteType.bluetooth:
        return Icons.bluetooth_audio_rounded;
      case AudioRouteType.headphones:
        return Icons.headphones_rounded;
      case AudioRouteType.airplay:
        return Icons.laptop_mac_rounded;
      case AudioRouteType.car:
        return Icons.directions_car_filled_rounded;
      case AudioRouteType.usb:
        return Icons.usb_rounded;
      case AudioRouteType.unknown:
        return Icons.speaker_rounded;
    }
  }

  String get subtitle {
    if (batteryLevel != null) {
      return '🔋 $batteryLevel%';
    }
    switch (type) {
      case AudioRouteType.speaker:
        return 'Built-in Speaker';
      case AudioRouteType.airpods:
        return 'Wireless High-Res Audio';
      case AudioRouteType.bluetooth:
        return 'Bluetooth Audio';
      case AudioRouteType.headphones:
        return 'Wired Headset';
      case AudioRouteType.airplay:
        return 'AirPlay / Screen Audio';
      case AudioRouteType.car:
        return 'Car System Audio';
      case AudioRouteType.usb:
        return 'USB Audio Interface';
      case AudioRouteType.unknown:
        return 'Audio Output';
    }
  }
}
