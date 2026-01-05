/// Impedance Provider - Alternative Impedance
/// State management based on ImpedanceMeasurementViewModel.kt

import 'package:flutter/foundation.dart';
import '../models/impedance_data.dart';
import '../services/ble_service.dart';
import '../services/firebase_service.dart';
import '../utils/constants.dart';

class ImpedanceProvider extends ChangeNotifier {
  final BleService _bleService = BleService();
  final FirebaseService _firebaseService = FirebaseService();

  // BLE State
  BleConnectionState get connectionState => _bleService.connectionState;
  BleProgramState get programState => _bleService.programState;
  String get deviceName => _bleService.deviceName;
  String get deviceAddress => _bleService.deviceAddress;
  String get innerDeviceId => _bleService.innerDeviceId;
  bool get isConnected => _bleService.isConnected;
  bool get isProgrammed => _bleService.isProgrammed;
  bool get isScanning => _bleService.isScanning;
  List<BleDeviceInfo> get scannedDevices => _bleService.scannedDevices;

  // Measurement State
  Map<int, double> _measurements = {};
  Map<int, double> get measurements => Map.unmodifiable(_measurements);

  // Separated measurements for charts
  Map<int, double> get measurements1to16 {
    final result = <int, double>{};
    for (int i = 1; i <= 16; i++) {
      if (_measurements.containsKey(i)) {
        result[i] = _measurements[i]!;
      }
    }
    return result;
  }

  Map<int, double> get measurements17to32 {
    final result = <int, double>{};
    for (int i = 17; i <= 32; i++) {
      if (_measurements.containsKey(i)) {
        result[i] = _measurements[i]!;
      }
    }
    return result;
  }

  bool _isMeasuring = false;
  bool get isMeasuring => _isMeasuring;

  bool _isMeasurementComplete = false;
  bool get isMeasurementComplete => _isMeasurementComplete;

  // Calibration Data (from chart point selection)
  CalibrationData _calibrationData = CalibrationData();
  CalibrationData get calibrationData => _calibrationData;

  // Measurement Parameters
  MeasurementParams _measurementParams = MeasurementParams();
  MeasurementParams get measurementParams => _measurementParams;

  // Diagnosed Measurements
  List<DiagnosedMeasurement> _diagnosedMeasurements = [];
  List<DiagnosedMeasurement> get diagnosedMeasurements => _diagnosedMeasurements;

  // Error state
  bool _isError = false;
  bool get isError => _isError;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  // Loading states
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Message callback
  Function(String)? onMessage;

  ImpedanceProvider() {
    _initializeCallbacks();
    _bleService.addListener(_onBleServiceChange);
  }

  void _initializeCallbacks() {
    _bleService.onMessage = (message) {
      onMessage?.call(message);
    };

    _bleService.onMeasurementComplete = (measurements) {
      _measurements = Map.from(measurements);
      _isMeasuring = false;
      _isMeasurementComplete = true;
      notifyListeners();
    };

    _bleService.onError = (error) {
      _isError = true;
      _errorMessage = error;
      _isMeasuring = false;
      onMessage?.call(error);
      notifyListeners();
    };
  }

  void _onBleServiceChange() {
    notifyListeners();
  }

  // ========== BLE Operations ==========

  /// Initialize BLE
  Future<void> initializeBle() async {
    await _bleService.initialize();
  }

  /// Start scanning for devices
  Future<void> startScan() async {
    await _bleService.startScan();
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await _bleService.stopScan();
  }

  /// Connect to device
  Future<bool> connectToDevice(BleDeviceInfo device) async {
    _isLoading = true;
    notifyListeners();

    final result = await _bleService.connectToDevice(device);

    _isLoading = false;
    notifyListeners();
    return result;
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    await _bleService.disconnect();
  }

  /// Send program start
  Future<bool> sendProgramStart() async {
    return await _bleService.sendProgramStart();
  }

  /// Send program end
  Future<bool> sendProgramEnd() async {
    return await _bleService.sendProgramEnd();
  }

  // ========== Measurement Operations ==========

  /// Start impedance measurement
  Future<bool> startMeasurement() async {
    _isError = false;
    _errorMessage = '';
    _isMeasuring = true;
    _isMeasurementComplete = false;
    _measurements.clear();
    _diagnosedMeasurements.clear();
    _calibrationData.clear();
    notifyListeners();

    final result = await _bleService.startMeasurement(_measurementParams);
    
    if (!result) {
      _isMeasuring = false;
      notifyListeners();
    }
    
    return result;
  }

  /// Clear current measurements
  void clearMeasurements() {
    _measurements.clear();
    _isMeasurementComplete = false;
    _diagnosedMeasurements.clear();
    _calibrationData.clear();
    _isError = false;
    _errorMessage = '';
    _bleService.clearMeasurements();
    notifyListeners();
  }

  /// Update measurements (for testing/simulation)
  void updateMeasurements(Map<int, double> newMeasurements) {
    _measurements = Map.from(newMeasurements);
    _isMeasurementComplete = newMeasurements.isNotEmpty;
    notifyListeners();
  }

  // ========== Calibration Operations ==========

  /// Update calibration data for channel 1-16 Min point
  void setChannel1to16Min(double impedanceValue, int frequencyValue) {
    _calibrationData.combin1At1to16Min = impedanceValue.toString();
    _calibrationData.resist1At1to16Min = frequencyValue.toString();
    notifyListeners();
  }

  /// Update calibration data for channel 1-16 Max point
  void setChannel1to16Max(double impedanceValue, int frequencyValue) {
    _calibrationData.combin1At1to16Max = impedanceValue.toString();
    _calibrationData.resist1At1to16Max = frequencyValue.toString();

    // Calculate slope and intercept
    _calculateSlopeIntercept1to16();
    notifyListeners();
  }

  /// Update calibration data for channel 17-32 Min point
  void setChannel17to32Min(double impedanceValue, int frequencyValue) {
    _calibrationData.combin1At17to32Min = impedanceValue.toString();
    _calibrationData.resist1At17to32Min = frequencyValue.toString();
    notifyListeners();
  }

  /// Update calibration data for channel 17-32 Max point
  void setChannel17to32Max(double impedanceValue, int frequencyValue) {
    _calibrationData.combin1At17to32Max = impedanceValue.toString();
    _calibrationData.resist1At17to32Max = frequencyValue.toString();

    // Calculate slope and intercept
    _calculateSlopeIntercept17to32();
    notifyListeners();
  }

  /// Calculate slope and intercept for channel 1-16
  /// Based on ImpedanceCombindation1Fragment.kt calculation
  void _calculateSlopeIntercept1to16() {
    final minImpedance = double.tryParse(_calibrationData.combin1At1to16Min) ?? 0;
    final maxImpedance = double.tryParse(_calibrationData.combin1At1to16Max) ?? 0;
    final minFreq = int.tryParse(_calibrationData.resist1At1to16Min) ?? 0;
    final maxFreq = int.tryParse(_calibrationData.resist1At1to16Max) ?? 0;

    if (maxImpedance != minImpedance) {
      final slope = (maxFreq - minFreq) / (maxImpedance - minImpedance);
      final intercept = minFreq - (slope * minImpedance);

      _calibrationData.combin1At1to16Inclin = slope.toStringAsFixed(5);
      _calibrationData.combin1At1to16Cap = intercept.toStringAsFixed(5);
    }
  }

  /// Calculate slope and intercept for channel 17-32
  void _calculateSlopeIntercept17to32() {
    final minImpedance = double.tryParse(_calibrationData.combin1At17to32Min) ?? 0;
    final maxImpedance = double.tryParse(_calibrationData.combin1At17to32Max) ?? 0;
    final minFreq = int.tryParse(_calibrationData.resist1At17to32Min) ?? 0;
    final maxFreq = int.tryParse(_calibrationData.resist1At17to32Max) ?? 0;

    if (maxImpedance != minImpedance) {
      final slope = (maxFreq - minFreq) / (maxImpedance - minImpedance);
      final intercept = minFreq - (slope * minImpedance);

      _calibrationData.combin1At17to32Inclin = slope.toStringAsFixed(5);
      _calibrationData.combin1At17to32Cap = intercept.toStringAsFixed(5);
    }
  }

  /// Clear calibration data
  void clearCalibration() {
    _calibrationData.clear();
    notifyListeners();
  }

  // ========== Diagnosis Operations ==========

  /// Diagnose measurements using calibration data from Firebase
  /// Based on checkMeasurementsInRange from NewImpedanceActivity.kt
  Future<List<DiagnosedMeasurement>> diagnoseWithFirebaseCalibration() async {
    if (_bleService.innerDeviceId.isEmpty || 
        _bleService.innerDeviceId == '--------' ||
        _measurements.isEmpty) {
      return [];
    }

    // Get calibration data from Firebase
    final calibration = await _firebaseService.getCalibrationData(_bleService.innerDeviceId);
    if (calibration == null) {
      return [];
    }

    return _diagnoseMeasurements(calibration);
  }

  /// Diagnose measurements using current calibration data
  List<DiagnosedMeasurement> diagnoseWithCurrentCalibration() {
    if (!_calibrationData.isValid || _measurements.isEmpty) {
      return [];
    }

    return _diagnoseMeasurements(_calibrationData);
  }

  /// Internal diagnosis method
  List<DiagnosedMeasurement> _diagnoseMeasurements(CalibrationData calibration) {
    _diagnosedMeasurements.clear();

    final min1to16 = double.tryParse(calibration.combin1At1to16Min) ?? 0;
    final max1to16 = double.tryParse(calibration.combin1At1to16Max) ?? double.infinity;
    final slope1to16 = double.tryParse(calibration.combin1At1to16Inclin) ?? 0;
    final intercept1to16 = double.tryParse(calibration.combin1At1to16Cap) ?? 0;

    final min17to32 = double.tryParse(calibration.combin1At17to32Min) ?? 0;
    final max17to32 = double.tryParse(calibration.combin1At17to32Max) ?? double.infinity;
    final slope17to32 = double.tryParse(calibration.combin1At17to32Inclin) ?? 0;
    final intercept17to32 = double.tryParse(calibration.combin1At17to32Cap) ?? 0;

    for (var entry in _measurements.entries) {
      final channel = entry.key;
      final value = entry.value;

      DiagnosedMeasurement diagnosed;
      if (channel <= 16) {
        diagnosed = DiagnosedMeasurement.fromMeasurement(
          channel: channel,
          value: value,
          minThreshold: min1to16,
          maxThreshold: max1to16,
          slope: slope1to16,
          intercept: intercept1to16,
        );
      } else {
        diagnosed = DiagnosedMeasurement.fromMeasurement(
          channel: channel,
          value: value,
          minThreshold: min17to32,
          maxThreshold: max17to32,
          slope: slope17to32,
          intercept: intercept17to32,
        );
      }

      _diagnosedMeasurements.add(diagnosed);
    }

    // Sort by channel
    _diagnosedMeasurements.sort((a, b) => a.channel.compareTo(b.channel));
    notifyListeners();

    return _diagnosedMeasurements;
  }

  // ========== Parameter Operations ==========

  /// Update measurement parameters
  void updateMeasurementParams(MeasurementParams params) {
    _measurementParams = params;
    notifyListeners();
  }

  /// Reset measurement parameters to defaults
  void resetMeasurementParams() {
    _measurementParams.reset();
    notifyListeners();
  }

  // ========== Firebase Operations ==========

  /// Save calibration data to Firebase
  Future<bool> saveCalibrationToFirebase() async {
    if (!_calibrationData.isValid || _measurements.isEmpty) {
      return false;
    }

    final date = _getCurrentDate();
    return await _firebaseService.saveCalibrationData(
      innerID: _bleService.innerDeviceId,
      date: date,
      calibration: _calibrationData,
      measurements: _measurements,
    );
  }

  /// Save new impedance data to Firebase
  Future<bool> saveNewImpedanceToFirebase(Map<String, String> diagnosedMeasurements) async {
    final date = _getCurrentDate();
    return await _firebaseService.saveNewImpedanceData(
      innerID: _bleService.innerDeviceId,
      date: date,
      measurements: diagnosedMeasurements,
    );
  }

  /// Get calibration data from Firebase
  Future<CalibrationData?> getCalibrationFromFirebase() async {
    if (_bleService.innerDeviceId.isEmpty || _bleService.innerDeviceId == '--------') {
      return null;
    }
    return await _firebaseService.getCalibrationData(_bleService.innerDeviceId);
  }

  /// Check if calibration exists for current device
  Future<bool> hasCalibration() async {
    if (_bleService.innerDeviceId.isEmpty || _bleService.innerDeviceId == '--------') {
      return false;
    }
    return await _firebaseService.hasCalibrationData(_bleService.innerDeviceId);
  }

  // ========== Helper Methods ==========

  String _getCurrentDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  /// Get frequency for channel
  int getFrequencyForChannel(int channel) {
    final channelIndex = ((channel - 1) % 16) + 1;
    return AppConstants.frequencyMapping[channelIndex] ?? 0;
  }

  @override
  void dispose() {
    _bleService.removeListener(_onBleServiceChange);
    super.dispose();
  }
}
