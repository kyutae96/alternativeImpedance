/// Impedance Data Models
/// Based on original Android models: ImpedanceDataModel, ImpedanceFirebaseDataModel, NewImpedanceFirebaseDataModel


import '../utils/constants.dart';

/// Firebase data model for storing calibration parameters
/// Based on ImpedanceFirebaseDataModel.kt
class ImpedanceFirebaseDataModel {
  final String innerID;
  final String date;
  final String combin1At1to16Min;
  final String combin1At1to16Max;
  final String resist1At1to16Min;
  final String resist1At1to16Max;
  final String combin1At1to16Inclin;
  final String combin1At1to16Cap;
  final String combin1At17to32Min;
  final String combin1At17to32Max;
  final String resist1At17to32Min;
  final String resist1At17to32Max;
  final String combin1At17to32Inclin;
  final String combin1At17to32Cap;
  final List<double> measurements1;

  ImpedanceFirebaseDataModel({
    required this.innerID,
    required this.date,
    required this.combin1At1to16Min,
    required this.combin1At1to16Max,
    required this.resist1At1to16Min,
    required this.resist1At1to16Max,
    required this.combin1At1to16Inclin,
    required this.combin1At1to16Cap,
    required this.combin1At17to32Min,
    required this.combin1At17to32Max,
    required this.resist1At17to32Min,
    required this.resist1At17to32Max,
    required this.combin1At17to32Inclin,
    required this.combin1At17to32Cap,
    required this.measurements1,
  });

  Map<String, dynamic> toJson() {
    return {
      'innerID': innerID,
      'date': date,
      'combin1At1to16Min': combin1At1to16Min,
      'combin1At1to16Max': combin1At1to16Max,
      'resist1At1to16Min': resist1At1to16Min,
      'resist1At1to16Max': resist1At1to16Max,
      'combin1At1to16Inclin': combin1At1to16Inclin,
      'combin1At1to16Cap': combin1At1to16Cap,
      'combin1At17to32Min': combin1At17to32Min,
      'combin1At17to32Max': combin1At17to32Max,
      'resist1At17to32Min': resist1At17to32Min,
      'resist1At17to32Max': resist1At17to32Max,
      'combin1At17to32Inclin': combin1At17to32Inclin,
      'combin1At17to32Cap': combin1At17to32Cap,
      'measurements1': measurements1,
    };
  }

  factory ImpedanceFirebaseDataModel.fromJson(Map<String, dynamic> json) {
    return ImpedanceFirebaseDataModel(
      innerID: json['innerID']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      combin1At1to16Min: json['combin1At1to16Min']?.toString() ?? '',
      combin1At1to16Max: json['combin1At1to16Max']?.toString() ?? '',
      resist1At1to16Min: json['resist1At1to16Min']?.toString() ?? '',
      resist1At1to16Max: json['resist1At1to16Max']?.toString() ?? '',
      combin1At1to16Inclin: json['combin1At1to16Inclin']?.toString() ?? '',
      combin1At1to16Cap: json['combin1At1to16Cap']?.toString() ?? '',
      combin1At17to32Min: json['combin1At17to32Min']?.toString() ?? '',
      combin1At17to32Max: json['combin1At17to32Max']?.toString() ?? '',
      resist1At17to32Min: json['resist1At17to32Min']?.toString() ?? '',
      resist1At17to32Max: json['resist1At17to32Max']?.toString() ?? '',
      combin1At17to32Inclin: json['combin1At17to32Inclin']?.toString() ?? '',
      combin1At17to32Cap: json['combin1At17to32Cap']?.toString() ?? '',
      measurements1: _parseDoubleList(json['measurements1']),
    );
  }

  static List<double> _parseDoubleList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => (e is num) ? e.toDouble() : 0.0).toList();
    }
    return [];
  }
}

/// Firebase data model for storing new impedance measurements
/// Based on NewImpedanceFirebaseDataModel.kt
class NewImpedanceFirebaseDataModel {
  final String innerID;
  final String date;
  final Map<String, String> measurements;

  NewImpedanceFirebaseDataModel({
    required this.innerID,
    required this.date,
    required this.measurements,
  });

  Map<String, dynamic> toJson() {
    return {
      'innerID': innerID,
      'date': date,
      'measurements': measurements,
    };
  }

  factory NewImpedanceFirebaseDataModel.fromJson(Map<String, dynamic> json) {
    final measurementsMap = <String, String>{};
    if (json['measurements'] is Map) {
      (json['measurements'] as Map).forEach((key, value) {
        measurementsMap[key.toString()] = value.toString();
      });
    }
    return NewImpedanceFirebaseDataModel(
      innerID: json['innerID']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      measurements: measurementsMap,
    );
  }
}

/// Local impedance data model for UI display
/// Based on ImpedanceDataModel.kt
class ImpedanceDataModel {
  final String combin1At1to16Min;
  final String combin1At1to16Max;
  final String resist1At1to16Min;
  final String resist1At1to16Max;
  final String combin1At1to16Inclin;
  final String combin1At1to16Cap;
  final String combin1At17to32Min;
  final String combin1At17to32Max;
  final String resist1At17to32Min;
  final String resist1At17to32Max;
  final String combin1At17to32Inclin;
  final String combin1At17to32Cap;
  final Map<int, double> measurements;

  ImpedanceDataModel({
    this.combin1At1to16Min = '---',
    this.combin1At1to16Max = '---',
    this.resist1At1to16Min = '---',
    this.resist1At1to16Max = '---',
    this.combin1At1to16Inclin = '기울기 : ---',
    this.combin1At1to16Cap = '절편 : ---',
    this.combin1At17to32Min = '---',
    this.combin1At17to32Max = '---',
    this.resist1At17to32Min = '---',
    this.resist1At17to32Max = '---',
    this.combin1At17to32Inclin = '기울기 : ---',
    this.combin1At17to32Cap = '절편 : ---',
    this.measurements = const {},
  });

  factory ImpedanceDataModel.empty() {
    return ImpedanceDataModel();
  }
}

/// Electrode status enum for diagnosis
enum ElectrodeStatus {
  normal,
  short,
  open,
  unknown,
}

/// Diagnosed measurement result
class DiagnosedMeasurement {
  final int channel;
  final double rawValue;
  final double calculatedValue;
  final int frequency;
  final ElectrodeStatus status;
  final String displayText;

  DiagnosedMeasurement({
    required this.channel,
    required this.rawValue,
    required this.calculatedValue,
    required this.frequency,
    required this.status,
    required this.displayText,
  });

  /// Create diagnosed measurement based on calibration data
  /// Based on checkValueInRange from NewImpedanceActivity.kt
  factory DiagnosedMeasurement.fromMeasurement({
    required int channel,
    required double value,
    required double minThreshold,
    required double maxThreshold,
    required double slope,
    required double intercept,
  }) {
    // Get frequency for this channel
    final channelIndex = ((channel - 1) % 16) + 1;
    final frequency = AppConstants.frequencyMapping[channelIndex] ?? 0;

    // Calculate capacitance/impedance value
    final calculatedValue = slope * value + intercept;

    // Determine status based on threshold comparison
    ElectrodeStatus status;
    String displayText;

    if (value < minThreshold) {
      status = ElectrodeStatus.short;
      displayText = '전극 쇼트 (${calculatedValue.toStringAsFixed(1)})';
    } else if (value > maxThreshold) {
      status = ElectrodeStatus.open;
      displayText = '전극 오픈 (${calculatedValue.toStringAsFixed(1)})';
    } else {
      status = ElectrodeStatus.normal;
      displayText = calculatedValue.toInt().toString();
    }

    return DiagnosedMeasurement(
      channel: channel,
      rawValue: value,
      calculatedValue: calculatedValue,
      frequency: frequency,
      status: status,
      displayText: displayText,
    );
  }
}

