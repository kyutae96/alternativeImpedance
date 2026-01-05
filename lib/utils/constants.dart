/// App Constants - Alternative Impedance
/// Based on original Android AppParam.kt

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConstants {
  // App Info
  static const String appName = 'Alternative Impedance';
  static const String appVersion = '1.0.0';

  // BLE UUIDs (from BLEController.kt)
  static const String bleServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const String bleCharacteristicTxUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e'; // Client to Server
  static const String bleCharacteristicRxUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e'; // Server to Client
  static const String bleCccdUuid = '00002902-0000-1000-8000-00805f9b34fb';
  static const String serviceDataUuid = '00004944-0000-1000-8000-00805F9B34FB';

  // BLE Command Values (from AppParam.kt)
  static const int commandProgramStart = 0x60;
  static const int commandProgramEnd = 0x61;
  static const int commandImpedanceMeasurement = 0x62;
  static const int commandInnerDeviceId = 0x91;
  static const int commandError = 0xF0;

  // Default Measurement Parameters (from AppParam.kt)
  static const int defaultRepeatCount = 10;
  static const int defaultChannelSelection = 255; // All channels
  static const int defaultNarrowPulseWidth = 15; // μs
  static const int defaultWidePulseWidth = 25; // μs
  static const int defaultStimulationLevel = 280;

  // Firebase Collection Names - Default Values
  static const String defaultMeasurementCollection = 'testNewImpedanceParam';
  static const String defaultCalibrationCollection = 'alternativeImpedanceParam';
  
  // Firebase Collection Options
  static const List<String> measurementCollectionOptions = [
    'testNewImpedanceParam',
    'alternativeNewImpedanceParam',
  ];
  
  static const List<String> calibrationCollectionOptions = [
    'testImpedanceParam',
    'alternativeImpedanceParam',
  ];

  // Legacy getters for backward compatibility
  static String get firestoreCollection => FirebaseSettings.measurementCollection;
  static String get firestoreParamCollection => FirebaseSettings.calibrationCollection;

  // Frequency Mapping (from ImpedanceCombindation1Fragment.kt)
  static const Map<int, int> frequencyMapping = {
    1: 300,
    2: 500,
    3: 1000,
    4: 1500,
    5: 2000,
    6: 2500,
    7: 3000,
    8: 4000,
    9: 5000,
    10: 6000,
    11: 7000,
    12: 8000,
    13: 9000,
    14: 10000,
    15: 12000,
    16: 15000,
  };

  // Channel frequency values (1-16 and 17-32 use same frequencies)
  static const List<int> channelFrequencies = [
    300, 500, 1000, 1500, 2000, 2500, 3000, 4000,
    5000, 6000, 7000, 8000, 9000, 10000, 12000, 15000,
  ];

  // Admin Password for Settings
  static const String adminPassword = 'todoc09876';

  // Diagnosis Thresholds
  static const double defaultMinThreshold = 2.0;
  static const double defaultMaxThreshold = 8.0;

  // Impedance Offset
  static const int impedanceOffset = 2048;

  // Total Channels
  static const int totalChannels = 32;
  static const int channelsPerGroup = 16;
}

/// Firebase Settings - Dynamic collection selection
class FirebaseSettings extends ChangeNotifier {
  static final FirebaseSettings _instance = FirebaseSettings._internal();
  factory FirebaseSettings() => _instance;
  FirebaseSettings._internal();

  String _measurementCollection = AppConstants.defaultMeasurementCollection;
  String _calibrationCollection = AppConstants.defaultCalibrationCollection;

  static String get measurementCollection => _instance._measurementCollection;
  static String get calibrationCollection => _instance._calibrationCollection;

  String get measurementCollectionValue => _measurementCollection;
  String get calibrationCollectionValue => _calibrationCollection;

  /// Initialize from SharedPreferences
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _measurementCollection = prefs.getString('measurementCollection') ?? AppConstants.defaultMeasurementCollection;
      _calibrationCollection = prefs.getString('calibrationCollection') ?? AppConstants.defaultCalibrationCollection;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading Firebase settings: $e');
    }
  }

  /// Set measurement collection
  Future<void> setMeasurementCollection(String collection) async {
    if (AppConstants.measurementCollectionOptions.contains(collection)) {
      _measurementCollection = collection;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('measurementCollection', collection);
      } catch (e) {
        debugPrint('Error saving measurement collection: $e');
      }
      notifyListeners();
    }
  }

  /// Set calibration collection
  Future<void> setCalibrationCollection(String collection) async {
    if (AppConstants.calibrationCollectionOptions.contains(collection)) {
      _calibrationCollection = collection;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('calibrationCollection', collection);
      } catch (e) {
        debugPrint('Error saving calibration collection: $e');
      }
      notifyListeners();
    }
  }
}

/// Measurement Parameters - Mutable state
class MeasurementParams {
  int repeatCount;
  int channelSelection;
  int narrowPulseWidth;
  int widePulseWidth;
  int stimulationLevel;

  MeasurementParams({
    this.repeatCount = AppConstants.defaultRepeatCount,
    this.channelSelection = AppConstants.defaultChannelSelection,
    this.narrowPulseWidth = AppConstants.defaultNarrowPulseWidth,
    this.widePulseWidth = AppConstants.defaultWidePulseWidth,
    this.stimulationLevel = AppConstants.defaultStimulationLevel,
  });

  /// Build parameter byte array for BLE command (from makeComination1Params)
  List<int> buildCommandPacket() {
    return [
      AppConstants.commandImpedanceMeasurement,
      repeatCount,
      channelSelection,
      narrowPulseWidth,
      widePulseWidth,
      (stimulationLevel >> 8) & 0xFF, // High byte
      stimulationLevel & 0xFF, // Low byte
    ];
  }

  MeasurementParams copyWith({
    int? repeatCount,
    int? channelSelection,
    int? narrowPulseWidth,
    int? widePulseWidth,
    int? stimulationLevel,
  }) {
    return MeasurementParams(
      repeatCount: repeatCount ?? this.repeatCount,
      channelSelection: channelSelection ?? this.channelSelection,
      narrowPulseWidth: narrowPulseWidth ?? this.narrowPulseWidth,
      widePulseWidth: widePulseWidth ?? this.widePulseWidth,
      stimulationLevel: stimulationLevel ?? this.stimulationLevel,
    );
  }

  void reset() {
    repeatCount = AppConstants.defaultRepeatCount;
    channelSelection = AppConstants.defaultChannelSelection;
    narrowPulseWidth = AppConstants.defaultNarrowPulseWidth;
    widePulseWidth = AppConstants.defaultWidePulseWidth;
    stimulationLevel = AppConstants.defaultStimulationLevel;
  }
}

/// Calibration Data for impedance to capacitance conversion
class CalibrationData {
  // Channel 1-16
  String combin1At1to16Min;
  String combin1At1to16Max;
  String resist1At1to16Min;
  String resist1At1to16Max;
  String combin1At1to16Inclin; // Slope
  String combin1At1to16Cap; // Intercept

  // Channel 17-32
  String combin1At17to32Min;
  String combin1At17to32Max;
  String resist1At17to32Min;
  String resist1At17to32Max;
  String combin1At17to32Inclin; // Slope
  String combin1At17to32Cap; // Intercept

  CalibrationData({
    this.combin1At1to16Min = '',
    this.combin1At1to16Max = '',
    this.resist1At1to16Min = '',
    this.resist1At1to16Max = '',
    this.combin1At1to16Inclin = '',
    this.combin1At1to16Cap = '',
    this.combin1At17to32Min = '',
    this.combin1At17to32Max = '',
    this.resist1At17to32Min = '',
    this.resist1At17to32Max = '',
    this.combin1At17to32Inclin = '',
    this.combin1At17to32Cap = '',
  });

  bool get isChannel1to16Valid =>
      combin1At1to16Min.isNotEmpty &&
      combin1At1to16Max.isNotEmpty &&
      combin1At1to16Inclin.isNotEmpty &&
      combin1At1to16Cap.isNotEmpty;

  bool get isChannel17to32Valid =>
      combin1At17to32Min.isNotEmpty &&
      combin1At17to32Max.isNotEmpty &&
      combin1At17to32Inclin.isNotEmpty &&
      combin1At17to32Cap.isNotEmpty;

  bool get isValid => isChannel1to16Valid && isChannel17to32Valid;

  void clear() {
    combin1At1to16Min = '';
    combin1At1to16Max = '';
    resist1At1to16Min = '';
    resist1At1to16Max = '';
    combin1At1to16Inclin = '';
    combin1At1to16Cap = '';
    combin1At17to32Min = '';
    combin1At17to32Max = '';
    resist1At17to32Min = '';
    resist1At17to32Max = '';
    combin1At17to32Inclin = '';
    combin1At17to32Cap = '';
  }

  Map<String, dynamic> toJson() {
    return {
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
    };
  }

  factory CalibrationData.fromJson(Map<String, dynamic> json) {
    return CalibrationData(
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
    );
  }
}
