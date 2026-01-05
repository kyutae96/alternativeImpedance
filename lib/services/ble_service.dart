/// BLE Service - Alternative Impedance
/// Complete reimplementation based on BLEController.kt from original Android app

import 'dart:async';
import 'dart:typed_data';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../utils/constants.dart';
import '../models/impedance_data.dart';

class BleService extends ChangeNotifier {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  // Connection state
  BleConnectionState _connectionState = BleConnectionState.disconnected;
  BleConnectionState get connectionState => _connectionState;

  // Program state
  BleProgramState _programState = BleProgramState.notStarted;
  BleProgramState get programState => _programState;

  // Device info
  String _deviceName = '연결된 기기 없음';
  String get deviceName => _deviceName;

  String _deviceAddress = '00:00:00:00:00:00';
  String get deviceAddress => _deviceAddress;

  String _innerDeviceId = '--------';
  String get innerDeviceId => _innerDeviceId;

  // BLE objects
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _txCharacteristic; // Client to Server
  BluetoothCharacteristic? _rxCharacteristic; // Server to Client
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _scanSubscription;

  // Measurement data buffers (from BLEController.kt)
  final Map<int, List<int>> _narrowPulseMap = {};
  final Map<int, List<int>> _widePulseMap = {};
  final List<int> _narrowPulseElectrode = [];
  final List<int> _widePulseElectrode = [];
  int _measurementRepetitions = AppConstants.defaultRepeatCount;

  // Measurement results
  Map<int, double> _measurements = {};
  Map<int, double> get measurements => Map.unmodifiable(_measurements);

  // Measurement state
  bool _isMeasurementFinished = false;
  bool get isMeasurementFinished => _isMeasurementFinished;

  bool _isError = false;
  bool get isError => _isError;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  // Scanned devices
  final List<BleDeviceInfo> _scannedDevices = [];
  List<BleDeviceInfo> get scannedDevices => List.unmodifiable(_scannedDevices);

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  // Callbacks
  Function(String)? onMessage;
  Function(Map<int, double>)? onMeasurementComplete;
  Function(String)? onError;

  /// Check if BLE is available (only on mobile platforms)
  /// Desktop platforms (Windows, macOS, Linux) use simulation mode
  bool get isBleAvailable {
    if (kIsWeb) return false;
    // On desktop platforms, BLE is not reliably supported
    // Use simulation mode for desktop
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        return false;
      }
      return true; // Android/iOS
    } catch (e) {
      return false;
    }
  }
  
  /// Check if running in simulation mode (web or desktop)
  bool get isSimulationMode => !isBleAvailable;

  /// Check if connected
  bool get isConnected => _connectionState == BleConnectionState.ready;

  /// Check if program started
  bool get isProgrammed => _programState == BleProgramState.started;

  /// Initialize BLE service
  Future<void> initialize() async {
    if (isSimulationMode) {
      debugPrint('BLE is not available on this platform - using simulation mode');
      return;
    }

    try {
      // Check if Bluetooth is available
      if (!await FlutterBluePlus.isSupported) {
        _setError('블루투스를 지원하지 않는 기기입니다.');
        return;
      }

      // Check Bluetooth state
      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        _setError('블루투스가 꺼져 있습니다. 블루투스를 켜주세요.');
        return;
      }
    } catch (e) {
      debugPrint('BLE initialization error: $e');
    }
  }

  /// Start scanning for BLE devices
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    if (isSimulationMode) {
      // Simulation mode for web/desktop
      await _simulateScan();
      return;
    }

    if (_isScanning) {
      await stopScan();
    }

    _scannedDevices.clear();
    _isScanning = true;
    notifyListeners();

    try {
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (var result in results) {
          final device = result.device;
          final name = device.platformName.isNotEmpty 
              ? device.platformName 
              : 'Unknown Device';
          
          // Filter for TODOC devices (devices starting with 'TD')
          if (name.startsWith('TD')) {
            final deviceInfo = BleDeviceInfo(
              name: name,
              address: device.remoteId.str,
              rssi: result.rssi,
            );
            
            if (!_scannedDevices.contains(deviceInfo)) {
              _scannedDevices.add(deviceInfo);
              notifyListeners();
            }
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: timeout);

      // Auto stop after timeout
      Future.delayed(timeout, () {
        if (_isScanning) {
          stopScan();
        }
      });
    } catch (e) {
      debugPrint('Scan error: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    if (isSimulationMode) {
      _isScanning = false;
      notifyListeners();
      return;
    }

    _isScanning = false;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('Stop scan error: $e');
    }
    notifyListeners();
  }

  /// Connect to device
  Future<bool> connectToDevice(BleDeviceInfo deviceInfo) async {
    if (isSimulationMode) {
      return _simulateConnect(deviceInfo);
    }

    try {
      _connectionState = BleConnectionState.connecting;
      notifyListeners();

      final device = BluetoothDevice.fromId(deviceInfo.address);
      _connectedDevice = device;

      // Connect to device
      await device.connect(timeout: const Duration(seconds: 15));

      // Listen for connection state changes
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        }
      });

      _connectionState = BleConnectionState.discovering;
      notifyListeners();

      // Discover services
      final services = await device.discoverServices();
      
      // Find our service
      BluetoothService? targetService;
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == AppConstants.bleServiceUuid.toLowerCase()) {
          targetService = service;
          break;
        }
      }

      if (targetService == null) {
        _setError('필요한 서비스를 포함하지 않은 기기입니다.');
        await disconnect();
        return false;
      }

      // Find characteristics
      for (var characteristic in targetService.characteristics) {
        final uuid = characteristic.uuid.toString().toLowerCase();
        if (uuid == AppConstants.bleCharacteristicTxUuid.toLowerCase()) {
          _txCharacteristic = characteristic;
        } else if (uuid == AppConstants.bleCharacteristicRxUuid.toLowerCase()) {
          _rxCharacteristic = characteristic;
        }
      }

      if (_txCharacteristic == null || _rxCharacteristic == null) {
        _setError('필요한 특성을 포함하지 않은 기기입니다.');
        await disconnect();
        return false;
      }

      // Enable notifications
      await _rxCharacteristic!.setNotifyValue(true);
      _notificationSubscription = _rxCharacteristic!.onValueReceived.listen(_handlePacket);

      // Update state
      _deviceName = deviceInfo.name;
      _deviceAddress = deviceInfo.address;
      _connectionState = BleConnectionState.ready;
      _programState = BleProgramState.notStarted;
      notifyListeners();

      onMessage?.call('기기에 연결되었습니다.');
      return true;

    } catch (e) {
      debugPrint('Connection error: $e');
      _setError('기기 연결에 실패했습니다: $e');
      await disconnect();
      return false;
    }
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    if (isSimulationMode) {
      _simulateDisconnect();
      return;
    }

    try {
      await _notificationSubscription?.cancel();
      await _connectionSubscription?.cancel();
      await _connectedDevice?.disconnect();
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }

    _handleDisconnection();
  }

  /// Handle disconnection
  void _handleDisconnection() {
    _connectedDevice = null;
    _txCharacteristic = null;
    _rxCharacteristic = null;
    _connectionState = BleConnectionState.disconnected;
    _programState = BleProgramState.notStarted;
    _deviceName = '연결된 기기 없음';
    _deviceAddress = '00:00:00:00:00:00';
    _innerDeviceId = '--------';
    notifyListeners();
  }

  /// Send program start command (0x60)
  Future<bool> sendProgramStart() async {
    if (isSimulationMode) {
      return _simulateProgramStart();
    }

    if (!isConnected || _txCharacteristic == null) {
      _setError('연결된 기기가 없습니다.');
      return false;
    }

    try {
      // Send program start command
      await _txCharacteristic!.write([AppConstants.commandProgramStart]);
      debugPrint('Program start packet sent');

      // Wait a bit then request inner device ID
      await Future.delayed(const Duration(milliseconds: 1000));
      await _txCharacteristic!.write([AppConstants.commandInnerDeviceId]);
      debugPrint('Inner device ID request sent');

      return true;
    } catch (e) {
      _setError('프로그램 시작 명령 전송 실패: $e');
      return false;
    }
  }

  /// Send program end command (0x61)
  Future<bool> sendProgramEnd() async {
    if (isSimulationMode) {
      return _simulateProgramEnd();
    }

    if (!isConnected || _txCharacteristic == null) {
      _setError('연결된 기기가 없습니다.');
      return false;
    }

    try {
      await _txCharacteristic!.write([AppConstants.commandProgramEnd]);
      debugPrint('Program end packet sent');
      return true;
    } catch (e) {
      _setError('프로그램 종료 명령 전송 실패: $e');
      return false;
    }
  }

  /// Start impedance measurement
  Future<bool> startMeasurement(MeasurementParams params) async {
    if (isSimulationMode) {
      return _simulateMeasurement(params);
    }

    if (!isConnected || !isProgrammed) {
      _setError('프로그램이 연결되지 않았습니다.');
      return false;
    }

    try {
      // Clear previous data
      _clearMeasurementData();
      _isMeasurementFinished = false;
      _isError = false;
      _programState = BleProgramState.measuring;
      notifyListeners();

      // Request inner device ID first
      await _txCharacteristic!.write([AppConstants.commandInnerDeviceId]);
      await Future.delayed(const Duration(milliseconds: 1000));

      // Clear maps again
      _narrowPulseMap.clear();
      _widePulseMap.clear();

      // Store measurement repetitions
      _measurementRepetitions = params.repeatCount;

      // Build and send measurement command
      final packet = params.buildCommandPacket();
      await _txCharacteristic!.write(packet);
      debugPrint('Measurement packet sent: $packet');

      return true;
    } catch (e) {
      _setError('측정 명령 전송 실패: $e');
      _programState = BleProgramState.error;
      notifyListeners();
      return false;
    }
  }

  /// Handle incoming BLE packet
  /// Based on onCharacteristicChanged from BLEController.kt
  void _handlePacket(List<int> packet) {
    if (packet.isEmpty) {
      debugPrint('Empty packet received');
      return;
    }

    debugPrint('Packet received: ${_bytesToHex(packet)}');

    final header = packet[0];

    switch (header) {
      case AppConstants.commandProgramStart: // 0x60
        _handleProgramStartResponse(packet);
        break;
      case AppConstants.commandProgramEnd: // 0x61
        _handleProgramEndResponse(packet);
        break;
      case AppConstants.commandImpedanceMeasurement: // 0x62
        _handleImpedanceData(packet);
        break;
      case AppConstants.commandInnerDeviceId: // 0x91
        _handleInnerDeviceId(packet);
        break;
      case AppConstants.commandError: // 0xF0
        _handleErrorPacket(packet);
        break;
      default:
        debugPrint('Unknown packet header: ${header.toRadixString(16)}');
    }
  }

  /// Handle program start response
  void _handleProgramStartResponse(List<int> packet) {
    if (packet.length < 2) {
      onMessage?.call('프로그램 연결 시작에 대하여 알 수 없는 패킷을 수신했습니다.');
      return;
    }

    if (packet[1] == 0x01) {
      _programState = BleProgramState.started;
      notifyListeners();
      onMessage?.call('프로그램 시작에 대하여 응답 패킷을 수신했습니다.');
    }
  }

  /// Handle program end response
  void _handleProgramEndResponse(List<int> packet) {
    if (packet.length < 2) {
      onMessage?.call('프로그램 연결 종료에 대하여 알 수 없는 패킷을 수신했습니다.');
      return;
    }

    if (packet[1] == 0x01) {
      _programState = BleProgramState.notStarted;
      notifyListeners();
      onMessage?.call('프로그램 연결 종료에 대하여 응답 패킷을 수신했습니다.');
    }
  }

  /// Handle impedance measurement data
  /// Based on the 0x62 packet handling in BLEController.kt
  void _handleImpedanceData(List<int> packet) {
    if (packet.length < 3) return;

    final electrodeNumber = packet[2] & 0xFF;
    if (electrodeNumber < 1 || electrodeNumber > 32) return;

    // Parse values based on packet size
    switch (packet.length) {
      case 19:
        // 4 measurement pairs
        _narrowPulseElectrode.add(((packet[3] & 0xFF) << 8) | (packet[4] & 0xFF));
        _narrowPulseElectrode.add(((packet[7] & 0xFF) << 8) | (packet[8] & 0xFF));
        _narrowPulseElectrode.add(((packet[11] & 0xFF) << 8) | (packet[12] & 0xFF));
        _narrowPulseElectrode.add(((packet[15] & 0xFF) << 8) | (packet[16] & 0xFF));

        _widePulseElectrode.add(((packet[5] & 0xFF) << 8) | (packet[6] & 0xFF));
        _widePulseElectrode.add(((packet[9] & 0xFF) << 8) | (packet[10] & 0xFF));
        _widePulseElectrode.add(((packet[13] & 0xFF) << 8) | (packet[14] & 0xFF));
        _widePulseElectrode.add(((packet[17] & 0xFF) << 8) | (packet[18] & 0xFF));
        break;
      case 15:
        // 3 measurement pairs
        _narrowPulseElectrode.add(((packet[3] & 0xFF) << 8) | (packet[4] & 0xFF));
        _narrowPulseElectrode.add(((packet[7] & 0xFF) << 8) | (packet[8] & 0xFF));
        _narrowPulseElectrode.add(((packet[11] & 0xFF) << 8) | (packet[12] & 0xFF));

        _widePulseElectrode.add(((packet[5] & 0xFF) << 8) | (packet[6] & 0xFF));
        _widePulseElectrode.add(((packet[9] & 0xFF) << 8) | (packet[10] & 0xFF));
        _widePulseElectrode.add(((packet[13] & 0xFF) << 8) | (packet[14] & 0xFF));
        break;
      case 11:
        // 2 measurement pairs
        _narrowPulseElectrode.add(((packet[3] & 0xFF) << 8) | (packet[4] & 0xFF));
        _narrowPulseElectrode.add(((packet[7] & 0xFF) << 8) | (packet[8] & 0xFF));

        _widePulseElectrode.add(((packet[5] & 0xFF) << 8) | (packet[6] & 0xFF));
        _widePulseElectrode.add(((packet[9] & 0xFF) << 8) | (packet[10] & 0xFF));
        break;
      case 7:
        // 1 measurement pair
        _narrowPulseElectrode.add(((packet[3] & 0xFF) << 8) | (packet[4] & 0xFF));
        _widePulseElectrode.add(((packet[5] & 0xFF) << 8) | (packet[6] & 0xFF));
        break;
    }

    // Check if we have enough samples for this electrode
    if (_narrowPulseElectrode.length >= _measurementRepetitions) {
      _narrowPulseMap[electrodeNumber] = List.from(_narrowPulseElectrode);
      _narrowPulseElectrode.clear();
    }

    if (_widePulseElectrode.length >= _measurementRepetitions) {
      _widePulseMap[electrodeNumber] = List.from(_widePulseElectrode);
      _widePulseElectrode.clear();
    }

    // Check if all 32 channels are measured
    if (_narrowPulseMap.length >= 32 && !_isMeasurementFinished) {
      _calculateMeasurements();
    }
  }

  /// Calculate final measurements
  /// Based on measurement calculation in BLEController.kt
  void _calculateMeasurements() {
    _measurements.clear();

    for (int key in _narrowPulseMap.keys) {
      // Skip first value (drop(1) in Kotlin)
      final narrowValues = _narrowPulseMap[key]!.skip(1).toList();
      final wideValues = _widePulseMap[key]?.skip(1).toList() ?? [];

      if (narrowValues.isNotEmpty && wideValues.isNotEmpty) {
        // Calculate average and subtract offset
        final narrowAvg = narrowValues.reduce((a, b) => a + b) / narrowValues.length - AppConstants.impedanceOffset;
        final wideAvg = wideValues.reduce((a, b) => a + b) / wideValues.length - AppConstants.impedanceOffset;

        // Final impedance is average of narrow and wide
        _measurements[key] = (narrowAvg + wideAvg) / 2;
      }
    }

    debugPrint('Measurements calculated: $_measurements');

    // Clear maps and set finished
    _narrowPulseMap.clear();
    _widePulseMap.clear();
    _isMeasurementFinished = true;
    _programState = BleProgramState.completed;
    notifyListeners();

    onMeasurementComplete?.call(Map.from(_measurements));
  }

  /// Handle inner device ID response
  /// Based on 0x91 handling in BLEController.kt
  void _handleInnerDeviceId(List<int> packet) {
    if (packet.length != 5) {
      debugPrint('Invalid inner device ID packet length: ${packet.length}');
      return;
    }

    // Extract hex string from bytes 1-4
    final hexString = packet.sublist(1, 5)
        .map((b) => (b & 0xFF).toRadixString(16).padLeft(2, '0'))
        .join();

    _innerDeviceId = hexString;
    notifyListeners();

    debugPrint('Inner device ID: $_innerDeviceId');
  }

  /// Handle error packet
  /// Based on 0xF0 handling in BLEController.kt
  void _handleErrorPacket(List<int> packet) {
    if (packet.length < 4) {
      onError?.call('에러 응답에 대하여 알 수 없는 패킷을 수신했습니다.');
      return;
    }

    // Parse error header
    String strHeader;
    switch (packet[1]) {
      case 0x60:
        strHeader = '프로그램 연결 시작';
        break;
      case 0x61:
        strHeader = '프로그램 연결 종료';
        break;
      case 0x62:
        strHeader = '임피던스 측정 명령';
        break;
      case 0x90:
        strHeader = '특정 자극(C-T)';
        break;
      default:
        strHeader = '알 수 없는';
    }

    // Parse error type and detail
    String strType;
    String strDetail = '알 수 없는 에러 상세';

    switch (packet[2]) {
      case 0x01:
        strType = 'CFX 에러';
        strDetail = '에러 상세 없음';
        break;
      case 0x02:
        strType = '데이터 처리 에러';
        strDetail = _getDataProcessingError(packet[3]);
        break;
      case 0x03:
        strType = '가속도 센서 에러';
        strDetail = _getSensorError(packet[3]);
        break;
      case 0x04:
        strType = 'RF PMIC 에러';
        strDetail = _getRfPmicError(packet[3]);
        break;
      case 0x05:
        strType = 'FPGA 통신 에러';
        strDetail = _getFpgaCommError(packet[3]);
        break;
      case 0x06:
        strType = 'FPGA 설정 에러';
        strDetail = _getFpgaSettingError(packet[3]);
        break;
      case 0x07:
        strType = '내부기';
        strDetail = _getInternalDeviceError(packet[3]);
        break;
      case 0x08:
        strType = '프로토콜 에러';
        strDetail = _getProtocolError(packet[3]);
        break;
      case 0x09:
        strType = 'PCM 발생';
        strDetail = _getPcmError(packet[3]);
        break;
      default:
        strType = '알 수 없는 에러';
    }

    final errorMessage = '$strHeader\n$strType\n$strDetail';
    _setError(errorMessage);
    _programState = BleProgramState.error;
    notifyListeners();
  }

  // Error detail helpers
  String _getDataProcessingError(int code) {
    switch (code) {
      case 0x01: return '사용할 수 없는 맵 데이터';
      case 0x02: return '자극 파라미터 업로드 안됨';
      default: return '알 수 없는 에러 상세';
    }
  }

  String _getSensorError(int code) {
    switch (code) {
      case 0x01: return '리셋 안됨';
      case 0x02: return '쓰기 오류';
      case 0x03: return '읽기 오류';
      default: return '알 수 없는 에러 상세';
    }
  }

  String _getRfPmicError(int code) {
    switch (code) {
      case 0x01: return '리셋 안됨';
      case 0x02: return 'TX 리셋 안됨';
      case 0x03: return '설정값이 제대로 설정 안됨';
      case 0x04: return '쓰기 오류';
      case 0x05: return '읽기 오류';
      default: return '알 수 없는 에러 상세';
    }
  }

  String _getFpgaCommError(int code) {
    switch (code) {
      case 0x01: return '리셋 안됨';
      case 0x02: return '쓰기 오류';
      case 0x03: return '읽기 오류';
      default: return '알 수 없는 에러 상세';
    }
  }

  String _getFpgaSettingError(int code) {
    switch (code) {
      case 0x01: return 'PCM 데이터로 설정안됨';
      case 0x02: return 'Tx 설정 오류';
      case 0x03: return '백텔 디코딩 교정 에러';
      case 0x04: return 'FIFO 비움 에러';
      case 0x05: return '펄스폭 설정 에러';
      default: return '알 수 없는 에러 상세';
    }
  }

  String _getInternalDeviceError(int code) {
    switch (code) {
      case 0x01: return '내부기 연결 안됨';
      case 0x02: return '내부기 EPROM 값 0';
      case 0x03: return '백텔이 카운터 0';
      case 0x04: return '벡텔 개수 적음';
      case 0x05: return '내부기 파워 낮음';
      case 0x06: return '내부기 파워 불안정';
      case 0x07: return '내부기 ID 불일치';
      case 0x08: return '최대 전달 전하량 초과';
      case 0x09: return '마스커, 프로브 인터벌 짧음';
      case 0x10: return '마스커, 프로브 인터벌 김';
      case 0x11: return '자극레벨 초과';
      case 0x12: return '자극 파라미터 설정 오류';
      case 0x13: return 'offset DAC 설정 오류';
      case 0x14: return '바이폴라 기준전극 설정 오류';
      default: return '알 수 없는 에러 상세';
    }
  }

  String _getProtocolError(int code) {
    switch (code) {
      case 0x01: return '이전 명령 진행 중';
      case 0x02: return '보안키 설정 전';
      case 0x03: return '명령 순서 오류';
      case 0x04: return '데이터 순서 오류';
      case 0x05: return '정의되지 않은 명령';
      case 0x06: return '데이터 범위 벗어남';
      default: return '알 수 없는 에러 상세';
    }
  }

  String _getPcmError(int code) {
    switch (code) {
      case 0x01: return 'PCM 버퍼 넘침';
      case 0x02: return 'PCM 템플릿 버퍼 넘침';
      default: return '알 수 없는 에러 상세';
    }
  }

  /// Clear measurement data
  void _clearMeasurementData() {
    _narrowPulseMap.clear();
    _widePulseMap.clear();
    _narrowPulseElectrode.clear();
    _widePulseElectrode.clear();
    _measurements.clear();
    _isMeasurementFinished = false;
    _isError = false;
    _errorMessage = '';
  }

  /// Set error state
  void _setError(String message) {
    _isError = true;
    _errorMessage = message;
    onError?.call(message);
    notifyListeners();
  }

  /// Clear measurements
  void clearMeasurements() {
    _measurements.clear();
    _isMeasurementFinished = false;
    notifyListeners();
  }

  /// Bytes to hex string helper
  String _bytesToHex(List<int> bytes) {
    return '0x${bytes.map((b) => (b & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}';
  }

  /// Dispose resources
  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _notificationSubscription?.cancel();
    _connectedDevice?.disconnect();
    super.dispose();
  }

  // ========== Web Simulation Methods ==========

  Future<void> _simulateScan() async {
    _scannedDevices.clear();
    _isScanning = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 2));

    _scannedDevices.addAll([
      BleDeviceInfo(name: 'TD-TODOC-001', address: 'AA:BB:CC:DD:EE:FF', rssi: -65),
      BleDeviceInfo(name: 'TD-TODOC-002', address: 'AA:BB:CC:DD:EE:00', rssi: -72),
    ]);

    _isScanning = false;
    notifyListeners();
  }

  Future<bool> _simulateConnect(BleDeviceInfo deviceInfo) async {
    _connectionState = BleConnectionState.connecting;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    _deviceName = deviceInfo.name;
    _deviceAddress = deviceInfo.address;
    _connectionState = BleConnectionState.ready;
    _programState = BleProgramState.notStarted;
    notifyListeners();

    onMessage?.call('[시뮬레이션] 기기에 연결되었습니다.');
    return true;
  }

  void _simulateDisconnect() {
    _handleDisconnection();
  }

  Future<bool> _simulateProgramStart() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _programState = BleProgramState.started;
    _innerDeviceId = '18210001';
    notifyListeners();
    onMessage?.call('[시뮬레이션] 프로그램 시작');
    return true;
  }

  Future<bool> _simulateProgramEnd() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _programState = BleProgramState.notStarted;
    notifyListeners();
    onMessage?.call('[시뮬레이션] 프로그램 종료');
    return true;
  }

  Future<bool> _simulateMeasurement(MeasurementParams params) async {
    _clearMeasurementData();
    _programState = BleProgramState.measuring;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 3));

    // Generate simulated measurements
    final random = DateTime.now().millisecondsSinceEpoch;
    for (int i = 1; i <= 32; i++) {
      _measurements[i] = 2.0 + (random % 100 + i) / 20.0; // Random values between 2.0 and 7.0
    }

    _isMeasurementFinished = true;
    _programState = BleProgramState.completed;
    notifyListeners();

    onMeasurementComplete?.call(Map.from(_measurements));
    return true;
  }
}
