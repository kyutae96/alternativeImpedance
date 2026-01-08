/// BLE Service - Web Implementation using Web Bluetooth API
/// Provides REAL BLE functionality for Chrome/Edge browsers
///
/// Requirements:
/// - Chrome 56+ or Edge 79+
/// - HTTPS connection (or localhost for development)
/// - User gesture required to initiate connection (button click)

// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import '../utils/constants.dart';
import 'ble_service_interface.dart';

/// Factory function for conditional import
BleServiceInterface createBleService() => BleServiceWeb();

// ========== Web Bluetooth JS Interop ==========

@JS('navigator.bluetooth')
external JSObject? get _navigatorBluetooth;

@JS('navigator.bluetooth.requestDevice')
external JSPromise<JSObject> _requestDevice(JSObject options);

@JS('navigator.bluetooth.getAvailability')
external JSPromise<JSBoolean> _getAvailability();

/// Extension for Web Bluetooth types
extension type BluetoothDevice._(JSObject _) implements JSObject {
  external String get id;
  external String? get name;
  external BluetoothRemoteGATTServer? get gatt;
  external set ongattserverdisconnected(JSFunction? handler);
}

extension type BluetoothRemoteGATTServer._(JSObject _) implements JSObject {
  external bool get connected;
  external BluetoothDevice get device;
  external JSPromise<BluetoothRemoteGATTServer> connect();
  external void disconnect();
  external JSPromise<BluetoothRemoteGATTService> getPrimaryService(JSString serviceUUID);
}

extension type BluetoothRemoteGATTService._(JSObject _) implements JSObject {
  external String get uuid;
  external JSPromise<BluetoothRemoteGATTCharacteristic> getCharacteristic(JSString characteristicUUID);
}

extension type BluetoothRemoteGATTCharacteristic._(JSObject _) implements JSObject {
  external String get uuid;
  external JSDataView? get value;
  external JSPromise<JSDataView> readValue();
  external JSPromise<JSAny?> writeValue(JSTypedArray data);
  external JSPromise<BluetoothRemoteGATTCharacteristic> startNotifications();
  external JSPromise<BluetoothRemoteGATTCharacteristic> stopNotifications();
  external set oncharacteristicvaluechanged(JSFunction? handler);
}

/// Check if Web Bluetooth is available
bool get _isWebBluetoothAvailable {
  try {
    return _navigatorBluetooth != null;
  } catch (e) {
    return false;
  }
}

class BleServiceWeb extends BleServiceInterface {
  static final BleServiceWeb _instance = BleServiceWeb._internal();
  factory BleServiceWeb() => _instance;
  BleServiceWeb._internal();

  // Web Bluetooth objects
  BluetoothDevice? _connectedDevice;
  BluetoothRemoteGATTServer? _gattServer;
  BluetoothRemoteGATTCharacteristic? _txCharacteristic;
  BluetoothRemoteGATTCharacteristic? _rxCharacteristic;

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

  @override
  bool get isBleAvailable => _isWebBluetoothAvailable;

  @override
  bool get isSimulationMode => false; // 실제 Web Bluetooth 사용

  @override
  bool get isConnected => _connectionState == BleConnectionState.ready;

  @override
  bool get isProgrammed => _programState == BleProgramState.started;

  @override
  String get platformName => 'Web Bluetooth (Chrome/Edge)';

  @override
  Future<void> initialize() async {
    if (!isBleAvailable) {
      debugPrint('❌ Web Bluetooth API is not available');
      debugPrint('Requirements: Chrome 56+ or Edge 79+, HTTPS connection');
      onError?.call('Web Bluetooth이 지원되지 않는 브라우저입니다.\nChrome 또는 Edge를 사용해주세요.');
    } else {
      debugPrint('✅ Web Bluetooth API is available');
      onMessage?.call('Web Bluetooth 준비 완료');
    }
  }

  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    if (!isBleAvailable) {
      _setError('Web Bluetooth이 지원되지 않습니다.');
      return;
    }

    _isScanning = true;
    _scannedDevices.clear();
    notifyListeners();

    try {
      onMessage?.call('브라우저 기기 선택 창이 열립니다...\nTD로 시작하는 기기를 선택해주세요.');

      // Web Bluetooth requestDevice options
      // 브라우저가 기기 선택 UI를 표시
      final options = <String, dynamic>{
        'filters': [
          {'namePrefix': 'TD'}  // TODOC 기기 필터
        ],
        'optionalServices': [
          AppConstants.bleServiceUuid.toLowerCase(),
        ]
      }.jsify();

      debugPrint('Requesting Bluetooth device...');
      final devicePromise = _requestDevice(options as JSObject);
      final device = await devicePromise.toDart as BluetoothDevice;

      debugPrint('Device selected: ${device.name ?? "Unknown"} (${device.id})');

      // 선택된 기기를 scannedDevices에 추가
      final deviceInfo = BleDeviceInfo(
        name: device.name ?? 'Unknown Device',
        address: device.id,
        rssi: 0,
        nativeDevice: device,
      );
      _scannedDevices.add(deviceInfo);
      notifyListeners();

      // 자동으로 연결 시도
      _isScanning = false;
      notifyListeners();
      
      await connectToDevice(deviceInfo);

    } catch (e) {
      debugPrint('Web Bluetooth error: $e');
      _isScanning = false;
      notifyListeners();

      if (e.toString().contains('cancelled') || e.toString().contains('canceled')) {
        onMessage?.call('기기 선택이 취소되었습니다.');
      } else if (e.toString().contains('NotFoundError')) {
        onError?.call('TD로 시작하는 기기를 찾을 수 없습니다.\n기기가 켜져 있는지 확인해주세요.');
      } else {
        _setError('BLE 스캔 실패: $e');
      }
    }
  }

  @override
  Future<void> stopScan() async {
    _isScanning = false;
    notifyListeners();
  }

  @override
  Future<bool> connectToDevice(BleDeviceInfo deviceInfo) async {
    try {
      _connectionState = BleConnectionState.connecting;
      notifyListeners();
      onMessage?.call('${deviceInfo.name}에 연결 중...');

      // Get the native device object
      BluetoothDevice? device;
      if (deviceInfo.nativeDevice != null) {
        device = deviceInfo.nativeDevice as BluetoothDevice;
      } else {
        _setError('유효하지 않은 기기입니다.');
        return false;
      }

      _connectedDevice = device;

      // Set disconnection handler
      device.ongattserverdisconnected = ((web.Event event) {
        debugPrint('GATT Server disconnected');
        _handleDisconnection();
        onMessage?.call('기기 연결이 해제되었습니다.');
      }).toJS;

      // Connect to GATT server
      _connectionState = BleConnectionState.connecting;
      notifyListeners();

      final gatt = device.gatt;
      if (gatt == null) {
        _setError('GATT 서버를 찾을 수 없습니다.');
        return false;
      }

      debugPrint('Connecting to GATT server...');
      _gattServer = await gatt.connect().toDart;
      debugPrint('GATT server connected');

      _connectionState = BleConnectionState.discovering;
      notifyListeners();
      onMessage?.call('서비스 검색 중...');

      // Get Nordic UART Service
      debugPrint('Getting primary service: ${AppConstants.bleServiceUuid}');
      final service = await _gattServer!
          .getPrimaryService(AppConstants.bleServiceUuid.toLowerCase().toJS)
          .toDart;
      debugPrint('Service found: ${service.uuid}');

      // Get TX Characteristic (Client to Server - Write)
      debugPrint('Getting TX characteristic: ${AppConstants.bleCharacteristicTxUuid}');
      _txCharacteristic = await service
          .getCharacteristic(AppConstants.bleCharacteristicTxUuid.toLowerCase().toJS)
          .toDart;
      debugPrint('TX characteristic found');

      // Get RX Characteristic (Server to Client - Notify)
      debugPrint('Getting RX characteristic: ${AppConstants.bleCharacteristicRxUuid}');
      _rxCharacteristic = await service
          .getCharacteristic(AppConstants.bleCharacteristicRxUuid.toLowerCase().toJS)
          .toDart;
      debugPrint('RX characteristic found');

      // Start notifications on RX characteristic
      debugPrint('Starting notifications...');
      await _rxCharacteristic!.startNotifications().toDart;
      
      // Set notification handler
      _rxCharacteristic!.oncharacteristicvaluechanged = ((web.Event event) {
        try {
          final target = (event.target as JSObject?) as BluetoothRemoteGATTCharacteristic?;
          if (target?.value != null) {
            final dataView = target!.value!;
            final bytes = _dataViewToBytes(dataView);
            debugPrint('Notification received: ${_bytesToHex(bytes)}');
            _handlePacket(bytes);
          }
        } catch (e) {
          debugPrint('Error handling notification: $e');
        }
      }).toJS;
      debugPrint('Notifications started');

      // Update state
      _deviceName = device.name ?? 'Unknown Device';
      _deviceAddress = device.id;
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

  List<int> _dataViewToBytes(JSDataView dataView) {
    // Access properties via js_interop
    final jsObj = dataView as JSObject;
    final byteLength = (jsObj['byteLength'] as JSNumber).toDartInt;
    
    final bytes = <int>[];
    for (int i = 0; i < byteLength; i++) {
      // Call getUint8 method
      final value = jsObj.callMethod('getUint8'.toJS, i.toJS) as JSNumber;
      bytes.add(value.toDartInt);
    }
    return bytes;
  }

  @override
  Future<void> disconnect() async {
    try {
      if (_rxCharacteristic != null) {
        try {
          await _rxCharacteristic!.stopNotifications().toDart;
        } catch (e) {
          debugPrint('Error stopping notifications: $e');
        }
      }
      
      _gattServer?.disconnect();
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }

    _handleDisconnection();
  }

  void _handleDisconnection() {
    _connectedDevice = null;
    _gattServer = null;
    _txCharacteristic = null;
    _rxCharacteristic = null;
    _connectionState = BleConnectionState.disconnected;
    _programState = BleProgramState.notStarted;
    _deviceName = '연결된 기기 없음';
    _deviceAddress = '00:00:00:00:00:00';
    _innerDeviceId = '--------';
    notifyListeners();
  }

  Future<void> _writeCharacteristic(List<int> data) async {
    if (_txCharacteristic == null) {
      throw Exception('TX characteristic not available');
    }

    final uint8Array = Uint8List.fromList(data).toJS;
    await _txCharacteristic!.writeValue(uint8Array).toDart;
    debugPrint('Wrote to TX: ${_bytesToHex(data)}');
  }

  @override
  Future<bool> sendProgramStart() async {
    if (!isConnected || _txCharacteristic == null) {
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
    if (!isConnected || _txCharacteristic == null) {
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

  /// Handle incoming BLE packet (same logic as mobile)
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

    // Parse values based on packet size (same as mobile)
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

  // Error detail helpers - Based on BLEController.kt
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
}
