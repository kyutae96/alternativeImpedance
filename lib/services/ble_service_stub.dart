/// BLE Service Stub - Default fallback implementation
/// Used when platform-specific implementation cannot be determined

import 'ble_service_interface.dart';
import '../utils/constants.dart';

BleServiceInterface createBleService() => BleServiceStub();

class BleServiceStub extends BleServiceInterface {
  static final BleServiceStub _instance = BleServiceStub._internal();
  factory BleServiceStub() => _instance;
  BleServiceStub._internal();

  @override
  BleConnectionState get connectionState => BleConnectionState.disconnected;
  
  @override
  BleProgramState get programState => BleProgramState.notStarted;
  
  @override
  String get deviceName => '연결된 기기 없음';
  
  @override
  String get deviceAddress => '00:00:00:00:00:00';
  
  @override
  String get innerDeviceId => '--------';
  
  @override
  Map<int, double> get measurements => {};
  
  @override
  bool get isMeasurementFinished => false;
  
  @override
  bool get isError => false;
  
  @override
  String get errorMessage => '';
  
  @override
  List<BleDeviceInfo> get scannedDevices => [];
  
  @override
  bool get isScanning => false;
  
  @override
  bool get isBleAvailable => false;
  
  @override
  bool get isSimulationMode => true;
  
  @override
  bool get isConnected => false;
  
  @override
  bool get isProgrammed => false;
  
  @override
  String get platformName => 'Stub (Unsupported Platform)';
  
  @override
  Function(String)? onMessage;
  
  @override
  Function(Map<int, double>)? onMeasurementComplete;
  
  @override
  Function(String)? onError;
  
  @override
  Future<void> initialize() async {}
  
  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {}
  
  @override
  Future<void> stopScan() async {}
  
  @override
  Future<bool> connectToDevice(BleDeviceInfo deviceInfo) async => false;
  
  @override
  Future<void> disconnect() async {}
  
  @override
  Future<bool> sendProgramStart() async => false;
  
  @override
  Future<bool> sendProgramEnd() async => false;
  
  @override
  Future<bool> startMeasurement(MeasurementParams params) async => false;
  
  @override
  void clearMeasurements() {}
}
