/// BLE Service - Platform-agnostic entry point
/// Automatically selects the correct implementation based on platform
///
/// - Web: Uses Web Bluetooth API (Chrome/Edge)
/// - Mobile (Android/iOS): Uses flutter_blue_plus
/// - Desktop: Falls back to simulation mode

export 'ble_service_interface.dart';

import 'package:flutter/foundation.dart';
import 'ble_service_interface.dart';

// Conditional imports
import 'ble_service_stub.dart'
    if (dart.library.html) 'ble_service_web.dart'
    if (dart.library.io) 'ble_service_mobile.dart' as platform_ble;

/// Factory class for creating platform-specific BLE service
class BleService {
  static BleServiceInterface? _instance;

  /// Get the singleton BLE service instance for the current platform
  static BleServiceInterface get instance {
    _instance ??= platform_ble.createBleService();
    return _instance!;
  }

  /// Alias for backwards compatibility
  factory BleService() => instance as dynamic;
}
