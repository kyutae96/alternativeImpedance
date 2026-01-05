/// BLE 기기 정보 모델
class BleDeviceInfo {
  final String id;
  final String name;
  final int rssi;
  final bool isConnected;
  final String? innerDeviceId; // 내부기 ID (8자리 hex)

  const BleDeviceInfo({
    required this.id,
    required this.name,
    this.rssi = 0,
    this.isConnected = false,
    this.innerDeviceId,
  });

  BleDeviceInfo copyWith({
    String? id,
    String? name,
    int? rssi,
    bool? isConnected,
    String? innerDeviceId,
  }) {
    return BleDeviceInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      isConnected: isConnected ?? this.isConnected,
      innerDeviceId: innerDeviceId ?? this.innerDeviceId,
    );
  }

  @override
  String toString() => 'BleDevice($name, $id, RSSI: $rssi)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleDeviceInfo &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// BLE 연결 상태
enum BleConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error;

  String get displayName {
    switch (this) {
      case BleConnectionState.disconnected:
        return '연결 해제';
      case BleConnectionState.connecting:
        return '연결 중...';
      case BleConnectionState.connected:
        return '연결됨';
      case BleConnectionState.disconnecting:
        return '연결 해제 중...';
      case BleConnectionState.error:
        return '연결 오류';
    }
  }
}

/// BLE 패킷 타입
class BlePacketType {
  static const int programStart = 0x60;
  static const int programEnd = 0x61;
  static const int impedanceMeasurement = 0x62;
  static const int innerDeviceId = 0x91;
  static const int error = 0xF0;
}

/// BLE UUID 정의
class BleUuids {
  static const String service = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const String characteristicTx = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
  static const String characteristicRx = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';
}

/// BLE 에러 분류
enum BleErrorCategory {
  cfxError(0x01, 'CFX 에러'),
  dataProcessError(0x02, '데이터 처리 에러'),
  accelerometerError(0x03, '가속도 센서 에러'),
  rfPmicError(0x04, 'RF PMIC 에러'),
  fpgaCommError(0x05, 'FPGA 통신 에러'),
  fpgaConfigError(0x06, 'FPGA 설정 에러'),
  innerDeviceError(0x07, '내부기 에러'),
  protocolError(0x08, '프로토콜 에러'),
  pcmError(0x09, 'PCM 발생 에러');

  final int code;
  final String description;

  const BleErrorCategory(this.code, this.description);

  static BleErrorCategory? fromCode(int code) {
    try {
      return BleErrorCategory.values.firstWhere((e) => e.code == code);
    } catch (_) {
      return null;
    }
  }
}
