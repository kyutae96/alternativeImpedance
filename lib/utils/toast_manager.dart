// Toast Manager - Single toast management
// Ensures only one toast is visible at a time

import 'package:flutter/material.dart';

class ToastManager {
  static final ToastManager _instance = ToastManager._internal();
  factory ToastManager() => _instance;
  ToastManager._internal();

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _currentSnackBar;

  /// Show a toast message, automatically dismissing any previous toast
  void showToast(BuildContext context, String message, {
    IconData? icon,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    // Dismiss current snackbar if exists
    _currentSnackBar?.close();
    
    // Clear any existing snackbars
    ScaffoldMessenger.of(context).clearSnackBars();

    // Show new snackbar
    _currentSnackBar = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: duration,
        backgroundColor: backgroundColor,
      ),
    );
  }

  /// Show success toast
  void showSuccess(BuildContext context, String message) {
    showToast(
      context,
      message,
      icon: Icons.check_circle_outline,
      backgroundColor: const Color(0xFF10B981),
    );
  }

  /// Show error toast
  void showError(BuildContext context, String message) {
    showToast(
      context,
      message,
      icon: Icons.error_outline,
      backgroundColor: const Color(0xFFEF4444),
    );
  }

  /// Show info toast
  void showInfo(BuildContext context, String message) {
    showToast(
      context,
      message,
      icon: Icons.info_outline,
    );
  }

  /// Clear all toasts
  void clearAll(BuildContext context) {
    _currentSnackBar?.close();
    ScaffoldMessenger.of(context).clearSnackBars();
    _currentSnackBar = null;
  }
}

// Global accessor
final toastManager = ToastManager();
