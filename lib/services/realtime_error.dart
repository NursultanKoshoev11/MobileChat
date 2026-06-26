bool isPermanentRealtimeConnectionError(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('403') ||
      text.contains('404') ||
      text.contains('forbidden') ||
      text.contains('not found');
}
