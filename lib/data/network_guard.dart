import 'dart:async';
import 'dart:math';

class CircuitOpenException implements Exception {
  const CircuitOpenException(this.message);
  final String message;
  @override
  String toString() => message;
}

class NetworkGuard {
  NetworkGuard({Random? random}) : _random = random ?? Random();

  static const int maxFailuresBeforeOpen = 5;
  static const Duration openDuration = Duration(seconds: 20);
  static const Duration baseDelay = Duration(milliseconds: 350);
  static const Duration maxDelay = Duration(seconds: 6);

  final Random _random;
  int _failures = 0;
  DateTime? _openUntil;

  void ensureAllowed() {
    final until = _openUntil;
    if (until != null && DateTime.now().isBefore(until)) {
      throw const CircuitOpenException('Network is temporarily unavailable. Please try again in a moment.');
    }
    if (until != null && DateTime.now().isAfter(until)) {
      _openUntil = null;
      _failures = 0;
    }
  }

  Future<void> waitBeforeRetry(int attempt) async {
    final exponentialMs = baseDelay.inMilliseconds * (1 << attempt.clamp(0, 4));
    final cappedMs = min(exponentialMs, maxDelay.inMilliseconds);
    final jitterMs = _random.nextInt(250);
    await Future<void>.delayed(Duration(milliseconds: cappedMs + jitterMs));
  }

  void recordSuccess() {
    _failures = 0;
    _openUntil = null;
  }

  void recordFailure() {
    _failures++;
    if (_failures >= maxFailuresBeforeOpen) {
      _openUntil = DateTime.now().add(openDuration);
    }
  }

  bool isRetryableStatus(int statusCode) =>
      statusCode == 408 || statusCode == 429 || statusCode == 500 || statusCode == 502 || statusCode == 503 || statusCode == 504;
}
