import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koom/app/firebase_config.dart';

void main() {
  const complete = {
    'apiKey': 'test-api-key',
    'appId': '1:123:ios:abc',
    'senderId': '123',
    'projectId': 'koom-test',
    'bundleId': 'com.example.koom',
  };

  test('iOS with complete build-time config returns explicit options', () {
    final options = firebaseOptionsForCurrentPlatform(
      platform: TargetPlatform.iOS,
      values: complete,
    );
    expect(options, isNotNull);
    expect(options!.appId, '1:123:ios:abc');
    expect(options.projectId, 'koom-test');
    expect(options.iosBundleId, 'com.example.koom');
  });

  test('iOS with missing values falls back to the native config', () {
    final partial = Map<String, String>.from(complete)..['appId'] = '';
    expect(
      firebaseOptionsForCurrentPlatform(
        platform: TargetPlatform.iOS,
        values: partial,
      ),
      isNull,
    );
  });

  test('Android always uses google-services.json', () {
    expect(
      firebaseOptionsForCurrentPlatform(
        platform: TargetPlatform.android,
        values: complete,
      ),
      isNull,
    );
  });
}
