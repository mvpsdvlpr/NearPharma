import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;
import 'package:buscafarmacia/src/config.dart';

void main() {
  test('AppConfig uses dotenv API_BASE_URL when no dart-define', () async {
    // Load a test env file located in the mobile/test directory
    await dotenv.load(fileName: 'test_env.env');
    final api = AppConfig.apiBase();
    expect(api, contains('test-dotenv.local'));
  });

  test('AppConfig falls back to localhost when no define or dotenv', () async {
    // Ensure no env loaded; load an empty file
    await dotenv.load(fileName: '.env');
    final api = AppConfig.apiBase();
    expect(api, contains('localhost'));
  });
}
