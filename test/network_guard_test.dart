import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat/data/network_guard.dart';

void main() {
  test('HTTP 429 is an API response, not a transport outage', () {
    final guard = NetworkGuard(random: Random(1));

    expect(guard.isRetryableStatus(429), isFalse);
    expect(guard.isRetryableStatus(408), isTrue);
    expect(guard.isRetryableStatus(500), isTrue);
    expect(guard.isRetryableStatus(502), isTrue);
    expect(guard.isRetryableStatus(503), isTrue);
    expect(guard.isRetryableStatus(504), isTrue);
  });
}
