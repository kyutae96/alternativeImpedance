// Font Size Provider - Global font size management
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontSizeProvider extends ChangeNotifier {
  static const String _fontScaleKey = 'font_scale';
  
  double _fontScale = 1.0;
  double get fontScale => _fontScale;
  
  // Font scale options
  static const double scaleSmall = 0.85;
  static const double scaleNormal = 1.0;
  static const double scaleLarge = 1.15;
  static const double scaleExtraLarge = 1.3;
  
  FontSizeProvider() {
    _loadFontScale();
  }
  
  Future<void> _loadFontScale() async {
    final prefs = await SharedPreferences.getInstance();
    _fontScale = prefs.getDouble(_fontScaleKey) ?? 1.0;
    notifyListeners();
  }
  
  Future<void> setFontScale(double scale) async {
    _fontScale = scale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontScaleKey, scale);
    notifyListeners();
  }
  
  String getFontScaleLabel() {
    if (_fontScale <= scaleSmall) return '작게';
    if (_fontScale <= scaleNormal) return '보통';
    if (_fontScale <= scaleLarge) return '크게';
    return '매우 크게';
  }
}
