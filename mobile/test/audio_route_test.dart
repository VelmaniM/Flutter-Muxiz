import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/audio_route.dart';

void main() {
  group('AudioRoute Model Tests', () {
    test('Correctly parses speaker route map', () {
      final map = {
        'id': 'speaker',
        'name': 'iPhone Speaker',
        'type': 'speaker',
        'isSelected': true,
        'isAvailable': true,
      };

      final route = AudioRoute.fromMap(map);
      expect(route.id, 'speaker');
      expect(route.name, 'iPhone Speaker');
      expect(route.type, AudioRouteType.speaker);
      expect(route.isSelected, true);
      expect(route.subtitle, 'Built-in Speaker');
    });

    test('Correctly parses AirPods route map with battery', () {
      final map = {
        'id': 'airpods_123',
        'name': 'Velmanikandan’s AirPods',
        'type': 'airpods',
        'isSelected': true,
        'isAvailable': true,
        'batteryLevel': 100,
      };

      final route = AudioRoute.fromMap(map);
      expect(route.id, 'airpods_123');
      expect(route.name, 'Velmanikandan’s AirPods');
      expect(route.type, AudioRouteType.airpods);
      expect(route.isSelected, true);
      expect(route.batteryLevel, 100);
      expect(route.subtitle, '🔋 100%');
    });

    test('Correctly parses AirPlay MacBook Air route map', () {
      final map = {
        'id': 'macbook_air',
        'name': 'Velmanikandan’s MacBook Air',
        'type': 'airplay',
        'isSelected': false,
        'isAvailable': true,
      };

      final route = AudioRoute.fromMap(map);
      expect(route.id, 'macbook_air');
      expect(route.name, 'Velmanikandan’s MacBook Air');
      expect(route.type, AudioRouteType.airplay);
      expect(route.isSelected, false);
      expect(route.subtitle, 'AirPlay / Screen Audio');
    });

    test('copyWith properly preserves immutability', () {
      const initial = AudioRoute(
        id: 'bt_1',
        name: 'BT-V09M',
        type: AudioRouteType.bluetooth,
        isSelected: false,
      );

      final updated = initial.copyWith(isSelected: true);
      expect(updated.isSelected, true);
      expect(initial.isSelected, false);
    });
  });
}
