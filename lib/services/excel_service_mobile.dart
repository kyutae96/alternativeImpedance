/// Excel Service - Mobile Implementation (Android/iOS)

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<String?> saveExcelFile(String fileName, List<int> bytes) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    debugPrint('Excel file saved: $filePath');
    return filePath;
  } catch (e) {
    debugPrint('Error saving Excel file: $e');
    return null;
  }
}

Future<bool> shareExcelFile(String filePath) async {
  try {
    final result = await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Alternative Impedance 측정 데이터',
    );
    return result.status == ShareResultStatus.success;
  } catch (e) {
    debugPrint('Error sharing Excel file: $e');
    return false;
  }
}
