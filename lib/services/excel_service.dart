/// Excel Export Service - Alternative Impedance
/// Based on exportAllToExcel in NewImpedanceAdapter.kt
/// Supports both mobile (file save + share) and web (download)

import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';

// Conditional imports for platform-specific functionality
import 'excel_service_stub.dart'
    if (dart.library.html) 'excel_service_web.dart'
    if (dart.library.io) 'excel_service_mobile.dart' as platform_excel;

class ExcelService {
  static final ExcelService _instance = ExcelService._internal();
  factory ExcelService() => _instance;
  ExcelService._internal();

  /// Export new impedance comparison data to Excel
  /// Based on exportAllToExcel from NewImpedanceAdapter.kt
  Future<String?> exportNewImpedanceData({
    required Map<int, String> measurements,
    String? fileName,
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['New Impedance Data'];
      excel.setDefaultSheet('New Impedance Data');

      // Reference frequency values (from NewImpedanceAdapter.kt)
      const indexList = [
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
        17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32
      ];
      const oldImpedanceValues = [
        300, 500, 1000, 1500, 2000, 2500, 3000, 4000,
        5000, 6000, 7000, 8000, 9000, 10000, 12000, 15000,
        300, 500, 1000, 1500, 2000, 2500, 3000, 4000,
        5000, 6000, 7000, 8000, 9000, 10000, 12000, 15000
      ];

      // Header row
      sheet.appendRow([
        TextCellValue('전극 번호'),
        TextCellValue('실제 저항값'),
        TextCellValue('측정 저항값'),
      ]);

      // Style header
      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );

      for (int col = 0; col < 3; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
        cell.cellStyle = headerStyle;
      }

      // Data rows
      for (int i = 0; i < indexList.length; i++) {
        final measurementValue = measurements[i] ?? 'N/A';
        sheet.appendRow([
          IntCellValue(indexList[i]),
          IntCellValue(oldImpedanceValues[i]),
          TextCellValue(measurementValue),
        ]);
      }

      // Set column widths
      sheet.setColumnWidth(0, 15);
      sheet.setColumnWidth(1, 20);
      sheet.setColumnWidth(2, 20);

      // Save file using platform-specific implementation
      final outputFileName = fileName ?? '측정_저항_비교_값_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final fileBytes = excel.save();
      
      if (fileBytes != null) {
        return await platform_excel.saveExcelFile(outputFileName, fileBytes);
      }

      return null;
    } catch (e) {
      debugPrint('Error exporting Excel: $e');
      return null;
    }
  }

  /// Export calibration data with measurements to Excel
  Future<String?> exportCalibrationData({
    required String innerID,
    required String date,
    required Map<int, double> measurements,
    required Map<String, String> calibrationParams,
    String? fileName,
  }) async {
    try {
      final excel = Excel.createExcel();
      
      // Sheet 1: Calibration Parameters
      final paramSheet = excel['Calibration Parameters'];
      excel.setDefaultSheet('Calibration Parameters');

      paramSheet.appendRow([TextCellValue('Parameter'), TextCellValue('Value')]);
      paramSheet.appendRow([TextCellValue('내부기 ID'), TextCellValue(innerID)]);
      paramSheet.appendRow([TextCellValue('날짜'), TextCellValue(date)]);
      
      calibrationParams.forEach((key, value) {
        paramSheet.appendRow([TextCellValue(key), TextCellValue(value)]);
      });

      // Sheet 2: Measurements
      final measurementSheet = excel['Measurements'];
      measurementSheet.appendRow([
        TextCellValue('채널'),
        TextCellValue('저항값 (Ω)'),
        TextCellValue('임피던스'),
      ]);

      for (int i = 1; i <= 32; i++) {
        final resistance = AppConstants.channelResistances[(i - 1) % 16];
        final impedance = measurements[i] ?? 0.0;
        measurementSheet.appendRow([
          IntCellValue(i),
          IntCellValue(resistance),
          DoubleCellValue(impedance),
        ]);
      }

      // Save file using platform-specific implementation
      final outputFileName = fileName ?? '캘리브레이션_${innerID}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final fileBytes = excel.save();
      
      if (fileBytes != null) {
        return await platform_excel.saveExcelFile(outputFileName, fileBytes);
      }

      return null;
    } catch (e) {
      debugPrint('Error exporting calibration Excel: $e');
      return null;
    }
  }

  /// Share Excel file (mobile only)
  Future<bool> shareExcelFile(String filePath) async {
    return await platform_excel.shareExcelFile(filePath);
  }

  /// Export and share in one step
  Future<bool> exportAndShare({
    required Map<int, String> measurements,
  }) async {
    final filePath = await exportNewImpedanceData(measurements: measurements);
    if (filePath != null) {
      return shareExcelFile(filePath);
    }
    return false;
  }
}
