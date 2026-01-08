/// BLE Service - Platform-agnostic entry point
/// Automatically selects the correct implementation based on platform
///
/// - Web: Uses Web Bluetooth API (Chrome/Edge)
/// - Mobile (Android/iOS): Uses flutter_blue_plus
/// - Windows Desktop: Uses win_ble for native BLE
/// - Other Desktop: Falls back to simulation mode

export 'ble_service_interface.dart';

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'ble_service_interface.dart';

// Conditional imports - base platform selection
import 'ble_service_stub.dart'
    if (dart.library.html) 'ble_service_web.dart'
    if (dart.library.io) 'ble_service_mobile.dart' as platform_ble;

// Windows-specific import
import 'ble_service_stub.dart'
    if (dart.library.io) 'ble_service_windows.dart' as windows_ble;

/// Factory class for creating platform-specific BLE service
class BleService {
  static BleServiceInterface? _instance;

  /// Get the singleton BLE service instance for the current platform
  static BleServiceInterface get instance {
    if (_instance == null) {
      if (kIsWeb) {
        // Web platform - use Web Bluetooth
        _instance = platform_ble.createBleService();
        debugPrint('BLE Service: Web Bluetooth mode');
      } else if (Platform.isWindows) {
        // Windows - use win_ble for native BLE
        _instance = windows_ble.createBleService();
        debugPrint('BLE Service: Windows Native BLE mode');
      } else if (Platform.isAndroid || Platform.isIOS) {
        // Mobile - use flutter_blue_plus
        _instance = platform_ble.createBleService();
        debugPrint('BLE Service: Mobile BLE mode');
      } else {
        // Other platforms - fallback
        _instance = platform_ble.createBleService();
        debugPrint('BLE Service: Fallback mode');
      }
    }
    return _instance!;
  }

  /// Alias for backwards compatibility
  factory BleService() => instance as dynamic;
}
