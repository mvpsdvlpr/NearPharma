import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(methodCount: 0),
  );

  /// Mask common sensitive keys in a map
  static Map<String, dynamic> maskMap(Map? m) {
    if (m == null) return {};
    final masked = <String, dynamic>{};
    m.forEach((k, v) {
      final key = k.toString().toLowerCase();
      if (key.contains('token') || key.contains('password') || key.contains('authorization')) {
        masked[k] = '****';
      } else {
        masked[k] = v;
      }
    });
    return masked;
  }

  static void d(String message, [dynamic error, StackTrace? st]) {
    if (kDebugMode) {
      _logger.d(message, error, st);
      print('[DEBUG] $message');
    }
  }

  static void i(String message, [dynamic error, StackTrace? st]) {
    if (kDebugMode) {
      _logger.i(message, error, st);
      print('[INFO] $message');
    }
  }

  static void e(String message, [dynamic error, StackTrace? st]) {
    // Always record errors to the internal logger but avoid printing in release.
    _logger.e(message, error, st);
    if (kDebugMode) print('[ERROR] $message');
  }
}
