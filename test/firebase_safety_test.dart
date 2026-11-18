import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koom/data/api_client.dart';
import 'package:koom/data/session_store.dart';
import 'package:koom/main.dart';
import 'package:koom/services/push_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('Firebase initialization failure never throws', () async {
    final ok = await initializeFirebaseSafely(
      initialize: () async => throw StateError('no GoogleService-Info.plist'),
    );
    expect(ok, isFalse);
  });

  test('Firebase initialization success is reported', () async {
    expect(await initializeFirebaseSafely(initialize: () async {}), isTrue);
  });

  test('push service no-ops safely without Firebase', () async {
    final service = PushNotificationService(
      api: ApiClient(
        baseUrl: 'https://koom.com.kg',
        sessionStore: const SessionStore(),
      ),
    );
    await service.registerDevice();
    await service.unregisterDevice();
    await service.forgetDeviceToken();
  });
}
