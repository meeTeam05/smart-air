import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/core/secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('getUserJson returns null and clears malformed JSON', () async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'user_json', value: '{broken-json');

    final secureStorage = SecureStorage();
    final userJson = await secureStorage.getUserJson();

    expect(userJson, isNull);
    expect(await storage.read(key: 'user_json'), isNull);
  });

  test('getUserJson returns null and clears non-object JSON', () async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'user_json', value: '["not","object"]');

    final secureStorage = SecureStorage();
    final userJson = await secureStorage.getUserJson();

    expect(userJson, isNull);
    expect(await storage.read(key: 'user_json'), isNull);
  });
}
