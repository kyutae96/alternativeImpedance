/// Excel Service - Web Implementation
/// Uses browser download for file saving

// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:typed_data';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

Future<String?> saveExcelFile(String fileName, List<int> bytes) async {
  try {
    // Convert to Uint8List then to JS
    final uint8List = Uint8List.fromList(bytes);
    final jsArray = uint8List.toJS;
    
    // Create blob from bytes
    final blob = web.Blob(
      [jsArray].toJS,
      web.BlobPropertyBag(type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
    );

    // Create download link
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = fileName;
    anchor.style.display = 'none';

    web.document.body?.appendChild(anchor);
    anchor.click();
    web.document.body?.removeChild(anchor);
    web.URL.revokeObjectURL(url);

    debugPrint('Excel file downloaded: $fileName');
    return fileName;
  } catch (e) {
    debugPrint('Error downloading Excel file: $e');
    return null;
  }
}

Future<bool> shareExcelFile(String filePath) async {
  // Web doesn't support native sharing in the same way
  // The file is already downloaded, so we return true
  debugPrint('Share not available on web - file was downloaded instead');
  return true;
}
