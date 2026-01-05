/// Firebase Service - Alternative Impedance
/// Based on Firebase operations in ImpedanceFragment.kt and NewImpedanceActivity.kt

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/impedance_data.dart';
import '../utils/constants.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save calibration parameters to Firebase
  /// Based on saveFireButton click handler in ImpedanceFragment.kt
  Future<bool> saveCalibrationData({
    required String innerID,
    required String date,
    required CalibrationData calibration,
    required Map<int, double> measurements,
  }) async {
    try {
      final measurementsList = <double>[];
      for (int i = 1; i <= 32; i++) {
        measurementsList.add(measurements[i] ?? 0.0);
      }

      final dataModel = ImpedanceFirebaseDataModel(
        innerID: innerID,
        date: date,
        combin1At1to16Min: calibration.combin1At1to16Min,
        combin1At1to16Max: calibration.combin1At1to16Max,
        resist1At1to16Min: calibration.resist1At1to16Min,
        resist1At1to16Max: calibration.resist1At1to16Max,
        combin1At1to16Inclin: calibration.combin1At1to16Inclin,
        combin1At1to16Cap: calibration.combin1At1to16Cap,
        combin1At17to32Min: calibration.combin1At17to32Min,
        combin1At17to32Max: calibration.combin1At17to32Max,
        resist1At17to32Min: calibration.resist1At17to32Min,
        resist1At17to32Max: calibration.resist1At17to32Max,
        combin1At17to32Inclin: calibration.combin1At17to32Inclin,
        combin1At17to32Cap: calibration.combin1At17to32Cap,
        measurements1: measurementsList,
      );

      await _firestore
          .collection(AppConstants.firestoreParamCollection)
          .doc(innerID)
          .set(dataModel.toJson());

      debugPrint('Calibration data saved for innerID: $innerID');
      return true;
    } catch (e) {
      debugPrint('Error saving calibration data: $e');
      return false;
    }
  }

  /// Save new impedance measurements to Firebase
  /// Based on saveFire() in NewImpedanceActivity.kt
  /// Uses testNewImpedanceParam collection (changed from alternativeNewImpedanceParam)
  Future<bool> saveNewImpedanceData({
    required String innerID,
    required String date,
    required Map<String, String> measurements,
  }) async {
    try {
      final dataModel = NewImpedanceFirebaseDataModel(
        innerID: innerID,
        date: date,
        measurements: measurements,
      );

      await _firestore
          .collection(AppConstants.firestoreCollection)
          .doc(innerID)
          .set(dataModel.toJson());

      debugPrint('New impedance data saved for innerID: $innerID');
      return true;
    } catch (e) {
      debugPrint('Error saving new impedance data: $e');
      return false;
    }
  }

  /// Get calibration parameters from Firebase for a given innerID
  /// Based on getNewImpedanceValueBtn click handler in ImpedanceFragment.kt
  Future<CalibrationData?> getCalibrationData(String innerID) async {
    try {
      final querySnapshot = await _firestore
          .collection(AppConstants.firestoreParamCollection)
          .where('innerID', isEqualTo: innerID)
          .get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint('No calibration data found for innerID: $innerID');
        return null;
      }

      final doc = querySnapshot.docs.first;
      return CalibrationData.fromJson(doc.data());
    } catch (e) {
      debugPrint('Error getting calibration data: $e');
      return null;
    }
  }

  /// Get all saved impedance parameter records
  Future<List<ImpedanceFirebaseDataModel>> getAllCalibrationData() async {
    try {
      final querySnapshot = await _firestore
          .collection(AppConstants.firestoreParamCollection)
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        return ImpedanceFirebaseDataModel.fromJson(doc.data());
      }).toList();
    } catch (e) {
      debugPrint('Error getting all calibration data: $e');
      return [];
    }
  }

  /// Get all saved new impedance records
  Future<List<NewImpedanceFirebaseDataModel>> getAllNewImpedanceData() async {
    try {
      final querySnapshot = await _firestore
          .collection(AppConstants.firestoreCollection)
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        return NewImpedanceFirebaseDataModel.fromJson(doc.data());
      }).toList();
    } catch (e) {
      debugPrint('Error getting all new impedance data: $e');
      return [];
    }
  }

  /// Check if calibration exists for innerID
  Future<bool> hasCalibrationData(String innerID) async {
    try {
      final querySnapshot = await _firestore
          .collection(AppConstants.firestoreParamCollection)
          .where('innerID', isEqualTo: innerID)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking calibration data: $e');
      return false;
    }
  }

  /// Delete calibration data
  Future<bool> deleteCalibrationData(String innerID) async {
    try {
      await _firestore
          .collection(AppConstants.firestoreParamCollection)
          .doc(innerID)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting calibration data: $e');
      return false;
    }
  }

  /// Delete new impedance data
  Future<bool> deleteNewImpedanceData(String innerID) async {
    try {
      await _firestore
          .collection(AppConstants.firestoreCollection)
          .doc(innerID)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting new impedance data: $e');
      return false;
    }
  }

  /// Listen to calibration data changes in real-time
  Stream<List<ImpedanceFirebaseDataModel>> watchCalibrationData() {
    return _firestore
        .collection(AppConstants.firestoreParamCollection)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ImpedanceFirebaseDataModel.fromJson(doc.data());
      }).toList();
    });
  }

  /// Listen to new impedance data changes in real-time
  Stream<List<NewImpedanceFirebaseDataModel>> watchNewImpedanceData() {
    return _firestore
        .collection(AppConstants.firestoreCollection)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return NewImpedanceFirebaseDataModel.fromJson(doc.data());
      }).toList();
    });
  }
}
