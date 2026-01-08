/// BLE Service - Windows Implementation using win_ble
/// Provides native BLE functionality for Windows desktop apps
///
/// Requirements:
/// - Windows 10 version 1803+ with Bluetooth 4.0+ support
/// - Bluetooth adapter enabled

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:win_ble/win_ble.dart';
import 'package:win_ble/win_file.dart';
import '../utils/constants.dart';
import 'ble_service_interface.dart';

/// Factory function for conditional import
BleServiceInterface createBleService() => BleServiceWindows();

class BleServiceWindows extends BleServiceInterface {
  static final BleServiceWindows _instance = BleServiceWindows._internal();
  factory BleServiceWindows() => _instance;
  BleServiceWindows._internal();

  // WinBle subscriptions
  StreamSubscription<BleDevice>? _scanSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<BleState>? _bleStateSubscription;
  StreamSubscription? _characteristicSubscription;
  String? _connectedDeviceAddress;

  // Connection state
  BleConnectionState _connectionState = BleConnectionState.disconnected;
  @override
  BleConnectionState get connectionState => _connectionState;

  // Program state
  BleProgramState _programState = BleProgramState.notStarted;
  @override
  BleProgramState get programState => _programState;

  // Device info
  String _deviceName = '연결된 기기 없음';
  @override
  String get deviceName => _deviceName;

  String _deviceAddress = '00:00:00:00:00:00';
  @override
  String get deviceAddress => _deviceAddress;

  String _innerDeviceId = '--------';
  @override
  String get innerDeviceId => _innerDeviceId;

  // Measurement data buffers
  final Map<int, List<int>> _narrowPulseMap = {};
  final Map<int, List<int>> _widePulseMap = {};
  final List<int> _narrowPulseElectrode = [];
  final List<int> _widePulseElectrode = [];
  int _measurementRepetitions = AppConstants.defaultRepeatCount;

  // Measurement results
  Map<int, double> _measurements = {};
  @override
  Map<int, double> get measurements => Map.unmodifiable(_measurements);

  // Measurement state
  bool _isMeasurementFinished = false;
  @override
  bool get isMeasurementFinished => _isMeasurementFinished;

  bool _isError = false;
  @override
  bool get isError => _isError;

  String _errorMessage = '';
  @override
  String get errorMessage => _errorMessage;

  // Scanned devices
  final List<BleDeviceInfo> _scannedDevices = [];
  @override
  List<BleDeviceInfo> get scannedDevices => List.unmodifiable(_scannedDevices);

  bool _isScanning = false;
  @override
  bool get isScanning => _isScanning;

  // Callbacks
  @override
  Function(String)? onMessage;
  @override
  Function(Map<int, double>)? onMeasurementComplete;
  @override
  Function(String)? onError;

  // BLE availability
  bool _isBleAvailable = false;
  bool _isInitialized = false;

  @override
  bool get isBleAvailable => _isBleAvailable;

  @override
  bool get isSimulationMode => false; // 실제 Windows BLE 사용

  @override
  bool get isConnected => _connectionState == BleConnectionState.ready;

  @override
  bool get isProgrammed => _programState == BleProgramState.started;

  @override
  String get platformName => 'Windows Native BLE';

  @override
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('Windows BLE already initialized');
      return;
    }

    try {
      debugPrint('Initializing Windows BLE...');
      
      // Get BLE server path for Flutter Windows
      final serverPath = await WinServer.path();
      debugPrint('BLE Server path: $serverPath');
      
      // Initialize WinBle
      await WinBle.initialize(
        serverPath: serverPath,
        enableLog: true,
      );

      _isInitialized = true;

      // Listen to BLE state changes
      _bleStateSubscription = WinBle.bleState.listen((state) {
        debugPrint('Windows BLE state: $state');
        _isBleAvailable = (state == BleState.On);
        notifyListeners();
      });

      // Check initial state
      final bleState = await WinBle.getBluetoothState();
      _isBleAvailable = (bleState == BleState.On);

      if (_isBleAvailable) {
        debugPrint('✅ Windows BLE initialized successfully');
        onMessage?.call('Windows BLE 준비 완료');
      } else {
        debugPrint('❌ Windows Bluetooth is OFF or unavailable');
        onError?.call('Bluetooth가 꺼져 있습니다.\nWindows 설정에서 Bluetooth를 켜주세요.');
      }
    } catch (e) {
      debugPrint('Windows BLE initialization error: $e');
      _isBleAvailable = false;
      _isInitialized = false;
      onError?.call('Windows BLE 초기화 실패: $e');
    }
  }

  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isBleAvailable) {
      _setError('Bluetooth를 사용할 수 없습니다.');
      return;
    }

    _isScanning = true;
    _scannedDevices.clear();
    notifyListeners();
    onMessage?.call('기기 검색 중...');

    try {
      // Start scanning
      WinBle.startScanning();

      // Listen to scan results
      _scanSubscription = WinBle.scanStream.listen((device) {
        // Filter for TD devices (TODOC)
        final deviceName = device.name;
        if (deviceName.startsWith('TD')) {
          final existingIndex = _scannedDevices.indexWhere(
            (d) => d.address == device.address,
          );

          final deviceInfo = BleDeviceInfo(
            name: deviceName,
            address: device.address,
            rssi: int.tryParse(device.rssi) ?? 0,
            nativeDevice: device,
          );

          if (existingIndex == -1) {
            _scannedDevices.add(deviceInfo);
            debugPrint('Found device: $deviceName (${device.address})');
            onMessage?.call('기기 발견: $deviceName');
          } else {
            _scannedDevices[existingIndex] = deviceInfo;
          }
          notifyListeners();
        }
      });

      // Auto-stop after timeout
      Future.delayed(timeout, () {
        if (_isScanning) {
          stopScan();
        }
      });

    } catch (e) {
      debugPrint('Scan error: $e');
      _setError('스캔 실패: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  @override
  Future<void> stopScan() async {
    try {
      WinBle.stopScanning();
      await _scanSubscription?.cancel();
      _scanSubscription = null;
    } catch (e) {
      debugPrint('Stop scan error: $e');
    }
    _isScanning = false;
    notifyListeners();
    onMessage?.call('스캔 완료 (${_scannedDevices.length}개 기기 발견)');
  }

  @override
  Future<bool> connectToDevice(BleDeviceInfo deviceInfo) async {
    try {
      _connectionState = BleConnectionState.connecting;
      notifyListeners();
      onMessage?.call('${deviceInfo.name}에 연결 중...');

      final address = deviceInfo.address;
      _connectedDeviceAddress = address;

      // Listen to connection state for this device
      _connectionSubscription = WinBle.connectionStreamOf(address).listen(
        (isConnected) {
          debugPrint('Connection state changed: $isConnected');
          if (!isConnected && _connectionState == BleConnectionState.ready) {
            _handleDisconnection();
            onMessage?.call('기기 연결이 해제되었습니다.');
          }
        },
        onError: (e) {
          debugPrint('Connection stream error: $e');
          _handleDisconnection();
        },
      );

      // Connect to device
      debugPrint('Connecting to $address...');
      await WinBle.connect(address);
      debugPrint('Connected to device');

      // Wait for connection to stabilize
      await Future.delayed(const Duration(milliseconds: 500));

      _connectionState = BleConnectionState.discovering;
      notifyListeners();
      onMessage?.call('서비스 검색 중...');

      // Discover services
      final services = await WinBle.discoverServices(address);
      debugPrint('Discovered ${services.length} services');

      // Find Nordic UART Service
      final targetServiceUuid = AppConstants.bleServiceUuid.toLowerCase();
      bool serviceFound = false;

      for (final service in services) {
        if (service.toLowerCase() == targetServiceUuid) {
          serviceFound = true;
          debugPrint('Found Nordic UART Service: $service');
          break;
        }
      }

      if (!serviceFound) {
        throw Exception('Nordic UART Service를 찾을 수 없습니다.');
      }

      // Subscribe to RX characteristic (notifications)
      debugPrint('Subscribing to RX characteristic...');
      await WinBle.subscribeToCharacteristic(
        address: address,
        serviceId: AppConstants.bleServiceUuid,
        characteristicId: AppConstants.bleCharacteristicRxUuid,
      );

      // Listen to characteristic value changes for this device
      _characteristicSubscription = WinBle.characteristicValueStreamOf(
        address: address,
        serviceId: AppConstants.bleServiceUuid,
        characteristicId: AppConstants.bleCharacteristicRxUuid,
      ).listen((value) {
        final bytes = List<int>.from(value);
        debugPrint('Notification received: ${_bytesToHex(bytes)}');
        _handlePacket(bytes);
      });

      debugPrint('Notifications started');

      // Update state
      _deviceName = deviceInfo.name;
      _deviceAddress = address;
      _connectionState = BleConnectionState.ready;
      _programState = BleProgramState.notStarted;
      notifyListeners();

      onMessage?.call('✅ ${_deviceName}에 연결되었습니다!');
      return true;

    } catch (e) {
      debugPrint('Connection error: $e');
      _setError('기기 연결 실패: $e');
      await disconnect();
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      if (_connectedDeviceAddress != null) {
        // Unsubscribe from characteristic
        try {
          await WinBle.unSubscribeFromCharacteristic(
            address: _connectedDeviceAddress!,
            serviceId: AppConstants.bleServiceUuid,
            characteristicId: AppConstants.bleCharacteristicRxUuid,
          );
        } catch (e) {
          debugPrint('Unsubscribe error: $e');
        }
        
        await WinBle.disconnect(_connectedDeviceAddress!);
      }
      await _connectionSubscription?.cancel();
      await _characteristicSubscription?.cancel();
      _connectionSubscription = null;
      _characteristicSubscription = null;
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }

    _handleDisconnection();
  }

  void _handleDisconnection() {
    _connectedDeviceAddress = null;
    _connectionState = BleConnectionState.disconnected;
    _programState = BleProgramState.notStarted;
    _deviceName = '연결된 기기 없음';
    _deviceAddress = '00:00:00:00:00:00';
    _innerDeviceId = '--------';
    notifyListeners();
  }

  Future<void> _writeCharacteristic(List<int> data) async {
    if (_connectedDeviceAddress == null) {
      throw Exception('연결된 기기가 없습니다.');
    }

    await WinBle.write(
      address: _connectedDeviceAddress!,
      service: AppConstants.bleServiceUuid,
      characteristic: AppConstants.bleCharacteristicTxUuid,
      data: Uint8List.fromList(data),
      writeWithResponse: false,
    );
    debugPrint('Wrote to TX: ${_bytesToHex(data)}');
  }

  @override
  Future<bool> sendProgramStart() async {
    if (!isConnected) {
      _setError('연결된 기기가 없습니다.');
      return false;
    }

    try {
      onMessage?.call('프로그램 시작 명령 전송 중...');

      // Send program start command (0x60)
      await _writeCharacteristic([AppConstants.commandProgramStart]);
      debugPrint('Program start packet sent');

      // Wait a bit then request inner device ID
      await Future.delayed(const Duration(milliseconds: 1000));
      await _writeCharacteristic([AppConstants.commandInnerDeviceId]);
      debugPrint('Inner device ID request sent');

      return true;
    } catch (e) {
      _setError('프로그램 시작 명령 전송 실패: $e');
      return false;
    }
  }

  @override
  Future<bool> sendProgramEnd() async {
    if (!isConnected) {
      _setError('연결된 기기가 없습니다.');
      return false;
    }

    try {
      await _writeCharacteristic([AppConstants.commandProgramEnd]);
      debugPrint('Program end packet sent');
      onMessage?.call('프로그램 종료 명령 전송');
      return true;
    } catch (e) {
      _setError('프로그램 종료 명령 전송 실패: $e');
      return false;
    }
  }

  @override
  Future<bool> startMeasurement(MeasurementParams params) async {
    if (!isConnected || !isProgrammed) {
      _setError('프로그램이 연결되지 않았습니다.');
      return false;
    }

    try {
      _clearMeasurementData();
      _isMeasurementFinished = false;
      _isError = false;
      _programState = BleProgramState.measuring;
      notifyListeners();
      onMessage?.call('임피던스 측정 시작...');

      // Request inner device ID first
      await _writeCharacteristic([AppConstants.commandInnerDeviceId]);
      await Future.delayed(const Duration(milliseconds: 1000));

      _narrowPulseMap.clear();
      _widePulseMap.clear();
      _measurementRepetitions = params.repeatCount;

      // Build and send measurement command
      final packet = params.buildCommandPacket();
      await _writeCharacteristic(packet);
      debugPrint('Measurement packet sent: $packet');

      return true;
    } catch (e) {
      _setError('측정 명령 전송 실패: $e');
      _programState = BleProgramState.error;
      notifyListeners();
      return false;
    }
  }

  /// Handle incoming BLE packet (same logic as mobile/web)
  void _handlePacket(List<int> packet) {
    if (packet.isEmpty) return;

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

  void _handleProgramStartResponse(List<int> packet) {
    if (packet.length >= 2 && packet[1] == 0x01) {
      _programState = BleProgramState.started;
      notifyListeners();
      onMessage?.call('✅ 프로그램 시작 완료');
    }
  }

  void _handleProgramEndResponse(List<int> packet) {
    if (packet.length >= 2 && packet[1] == 0x01) {
      _programState = BleProgramState.notStarted;
      notifyListeners();
      onMessage?.call('프로그램 종료 완료');
    }
  }

  void _handleImpedanceData(List<int> packet) {
    if (packet.length < 3) return;

    final electrodeNumber = packet[2] & 0xFF;
    if (electrodeNumber < 1 || electrodeNumber > 32) return;

    onMessage?.call('채널 $electrodeNumber 데이터 수신 중...');

    // Parse values based on packet size
    switch (packet.length) {
      case 19:
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
        _narrowPulseElectrode.add(((packet[3] & 0xFF) << 8) | (packet[4] & 0xFF));
        _narrowPulseElectrode.add(((packet[7] & 0xFF) << 8) | (packet[8] & 0xFF));
        _narrowPulseElectrode.add(((packet[11] & 0xFF) << 8) | (packet[12] & 0xFF));
        _widePulseElectrode.add(((packet[5] & 0xFF) << 8) | (packet[6] & 0xFF));
        _widePulseElectrode.add(((packet[9] & 0xFF) << 8) | (packet[10] & 0xFF));
        _widePulseElectrode.add(((packet[13] & 0xFF) << 8) | (packet[14] & 0xFF));
        break;
      case 11:
        _narrowPulseElectrode.add(((packet[3] & 0xFF) << 8) | (packet[4] & 0xFF));
        _narrowPulseElectrode.add(((packet[7] & 0xFF) << 8) | (packet[8] & 0xFF));
        _widePulseElectrode.add(((packet[5] & 0xFF) << 8) | (packet[6] & 0xFF));
        _widePulseElectrode.add(((packet[9] & 0xFF) << 8) | (packet[10] & 0xFF));
        break;
      case 7:
        _narrowPulseElectrode.add(((packet[3] & 0xFF) << 8) | (packet[4] & 0xFF));
        _widePulseElectrode.add(((packet[5] & 0xFF) << 8) | (packet[6] & 0xFF));
        break;
    }

    if (_narrowPulseElectrode.length >= _measurementRepetitions) {
      _narrowPulseMap[electrodeNumber] = List.from(_narrowPulseElectrode);
      _narrowPulseElectrode.clear();
    }

    if (_widePulseElectrode.length >= _measurementRepetitions) {
      _widePulseMap[electrodeNumber] = List.from(_widePulseElectrode);
      _widePulseElectrode.clear();
    }

    if (_narrowPulseMap.length >= 32 && !_isMeasurementFinished) {
      _calculateMeasurements();
    }
  }

  void _calculateMeasurements() {
    _measurements.clear();

    for (int key in _narrowPulseMap.keys) {
      final narrowValues = _narrowPulseMap[key]!.skip(1).toList();
      final wideValues = _widePulseMap[key]?.skip(1).toList() ?? [];

      if (narrowValues.isNotEmpty && wideValues.isNotEmpty) {
        final narrowAvg = narrowValues.reduce((a, b) => a + b) / narrowValues.length - AppConstants.impedanceOffset;
        final wideAvg = wideValues.reduce((a, b) => a + b) / wideValues.length - AppConstants.impedanceOffset;
        _measurements[key] = (narrowAvg + wideAvg) / 2;
      }
    }

    debugPrint('Measurements calculated: $_measurements');

    _narrowPulseMap.clear();
    _widePulseMap.clear();
    _isMeasurementFinished = true;
    _programState = BleProgramState.completed;
    notifyListeners();

    onMeasurementComplete?.call(Map.from(_measurements));
    onMessage?.call('✅ 측정 완료! (32채널)');
  }

  void _handleInnerDeviceId(List<int> packet) {
    if (packet.length != 5) return;

    final hexString = packet.sublist(1, 5)
        .map((b) => (b & 0xFF).toRadixString(16).padLeft(2, '0'))
        .join();

    _innerDeviceId = hexString;
    notifyListeners();
    debugPrint('Inner device ID: $_innerDeviceId');
    onMessage?.call('내부기 ID: $_innerDeviceId');
  }

  /// Handle error packet - Based on BLEController.kt error handling
  void _handleErrorPacket(List<int> packet) {
    if (packet.length < 4) {
      _setError('에러 응답에 대하여 알 수 없는 패킷을 수신했습니다.');
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
        strType = '내부기 에러';
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
    debugPrint('BLE Error: $errorMessage');
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

  void _setError(String message) {
    _isError = true;
    _errorMessage = message;
    onError?.call(message);
    notifyListeners();
  }

  @override
  void clearMeasurements() {
    _measurements.clear();
    _isMeasurementFinished = false;
    notifyListeners();
  }

  String _bytesToHex(List<int> bytes) {
    return '0x${bytes.map((b) => (b & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}';
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _bleStateSubscription?.cancel();
    _characteristicSubscription?.cancel();
    if (_isInitialized) {
      WinBle.dispose();
      _isInitialized = false;
    }
    super.dispose();
  }
}
