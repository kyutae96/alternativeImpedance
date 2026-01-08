// Cache Service for Firebase data
// Reduces unnecessary API calls by caching data locally

import '../models/impedance_data.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // Cached data
  List<ImpedanceFirebaseDataModel>? _calibrationData;
  List<NewImpedanceFirebaseDataModel>? _impedanceData;

  // Cache timestamps
  DateTime? _calibrationCacheTime;
  DateTime? _impedanceCacheTime;

  // Cache duration (5 minutes)
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Check if calibration cache is valid
  bool get isCalibrationCacheValid {
    if (_calibrationData == null || _calibrationCacheTime == null) return false;
    return DateTime.now().difference(_calibrationCacheTime!) < _cacheDuration;
  }

  // Check if impedance cache is valid
  bool get isImpedanceCacheValid {
    if (_impedanceData == null || _impedanceCacheTime == null) return false;
    return DateTime.now().difference(_impedanceCacheTime!) < _cacheDuration;
  }

  // Get cached calibration data
  List<ImpedanceFirebaseDataModel>? get calibrationData {
    if (isCalibrationCacheValid) return _calibrationData;
    return null;
  }

  // Get cached impedance data
  List<NewImpedanceFirebaseDataModel>? get impedanceData {
    if (isImpedanceCacheValid) return _impedanceData;
    return null;
  }

  // Set calibration data cache
  void setCalibrationData(List<ImpedanceFirebaseDataModel> data) {
    _calibrationData = data;
    _calibrationCacheTime = DateTime.now();
  }

  // Set impedance data cache
  void setImpedanceData(List<NewImpedanceFirebaseDataModel> data) {
    _impedanceData = data;
    _impedanceCacheTime = DateTime.now();
  }

  // Invalidate calibration cache
  void invalidateCalibrationCache() {
    _calibrationData = null;
    _calibrationCacheTime = null;
  }

  // Invalidate impedance cache
  void invalidateImpedanceCache() {
    _impedanceData = null;
    _impedanceCacheTime = null;
  }

  // Invalidate all caches
  void invalidateAll() {
    invalidateCalibrationCache();
    invalidateImpedanceCache();
  }

  // Get cache status info
  Map<String, dynamic> getCacheStatus() {
    return {
      'calibrationCached': isCalibrationCacheValid,
      'calibrationCount': _calibrationData?.length ?? 0,
      'calibrationCacheAge': _calibrationCacheTime != null 
          ? DateTime.now().difference(_calibrationCacheTime!).inSeconds 
          : null,
      'impedanceCached': isImpedanceCacheValid,
      'impedanceCount': _impedanceData?.length ?? 0,
      'impedanceCacheAge': _impedanceCacheTime != null 
          ? DateTime.now().difference(_impedanceCacheTime!).inSeconds 
          : null,
    };
  }
}

// Global accessor
final cacheService = CacheService();
