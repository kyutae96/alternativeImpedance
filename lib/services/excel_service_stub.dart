/// Excel Service Stub - Default fallback implementation

import 'package:flutter/foundation.dart';

Future<String?> saveExcelFile(String fileName, List<int> bytes) async {
  debugPrint('Excel save not supported on this platform');
  return null;
}

Future<bool> shareExcelFile(String filePath) async {
  debugPrint('Excel share not supported on this platform');
  return false;
}
