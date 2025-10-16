// Small configuration helper that centralizes API base URL resolution.
// Resolution order:
// 1. Compile-time define: const String.fromEnvironment('API_BASE_URL')
// 2. flutter_dotenv value: dotenv.env['API_BASE_URL']
// 3. Fallback: http://localhost:3001

import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const _envKey = 'API_BASE_URL';

  /// Returns the resolved API base URL using the precedence described above.
  static String apiBase() {
    // 1. Check compile-time define (passed with --dart-define)
    const fromDefine = String.fromEnvironment(_envKey);
    if (fromDefine.isNotEmpty) return fromDefine;

    // 2. Then check dotenv (may be loaded already)
    final fromDotenv = dotenv.env[_envKey];
    if (fromDotenv != null && fromDotenv.isNotEmpty) return fromDotenv;

    // 3. Fallback to localhost dev server
    return 'http://localhost:3001';
  }
}
