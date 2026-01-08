/// BLE Service Interface - Platform-agnostic abstraction
/// Defines the common interface for BLE operations across all platforms

import 'package:flutter/foundation.dart';
import '../utils/constants.dart';

/// Connection states for BLE
enum BleConnectionState {
  disconnected,
  connecting,
  connected,
  discovering,
  ready,
  error,
}

/// Program states for BLE device
enum BleProgramState {
  notStarted,
  started,
  measuring,
  completed,
  error,
}

/// BLE Device Information
class BleDeviceInfo {
  final String name;
  final String address;
  final int rssi;
  final dynamic nativeDevice; // Platform-specific device object

  BleDeviceInfo({
    required this.name,
    required this.address,
    this.rssi = 0,
    this.nativeDevice,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleDeviceInfo &&
          runtimeType == other.runtimeType &&
          address == other.address;

  @override
  int get hashCode => address.hashCode;

  @override
  String toString() => 'BleDeviceInfo(name: $name, address: $address, rssi: $rssi)';
}

/// Abstract BLE Service Interface
/// All platform-specific implementations must extend this class
abstract class BleServiceInterface extends ChangeNotifier {
  // Connection state
  BleConnectionState get connectionState;
  BleProgramState get programState;
  
  // Device info
  String get deviceName;
  String get deviceAddress;
  String get innerDeviceId;
  
  // Measurement data
  Map<int, double> get measurements;
  bool get isMeasurementFinished;
  bool get isError;
  String get errorMessage;
  
  // Scan results
  List<BleDeviceInfo> get scannedDevices;
  bool get isScanning;
  
  // Platform info
  bool get isBleAvailable;
  bool get isSimulationMode;
  bool get isConnected;
  bool get isProgrammed;
  String get platformName;
  
  // Callbacks
  Function(String)? onMessage;
  Function(Map<int, double>)? onMeasurementComplete;
  Function(String)? onError;
  
  // Core BLE operations
  Future<void> initialize();
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)});
  Future<void> stopScan();
  Future<bool> connectToDevice(BleDeviceInfo deviceInfo);
  Future<void> disconnect();
  
  // Program operations
  Future<bool> sendProgramStart();
  Future<bool> sendProgramEnd();
  
  // Measurement operations
  Future<bool> startMeasurement(MeasurementParams params);
  void clearMeasurements();
}
