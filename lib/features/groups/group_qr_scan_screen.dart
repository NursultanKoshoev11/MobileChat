import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../shared/ui_helpers.dart';

export 'group_sheets.dart';

class GroupQrScanScreen extends StatefulWidget {
  const GroupQrScanScreen({super.key});

  @override
  State<GroupQrScanScreen> createState() => _GroupQrScanScreenState();
}

class _GroupQrScanScreenState extends State<GroupQrScanScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool handled = false;
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void handleDetect(BarcodeCapture capture) {
    if (handled) return;
    final rawValue = firstQrValue(capture);
    if (rawValue == null) return;

    final inviteCode = extractInviteCode(rawValue);
    if (inviteCode == null || inviteCode.isEmpty) {
      setState(() => error = AppLanguageScope.textOf(context).isKy
          ? 'Бул QR коддон чакыруу коду табылган жок.'
          : 'Не удалось найти код приглашения в этом QR.');
      return;
    }

    handled = true;
    Navigator.of(context).pop(inviteCode);
  }

  String? firstQrValue(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String? extractInviteCode(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri != null) {
      final queryKeys = ['invite_code', 'inviteCode', 'code', 'group_code'];
      for (final key in queryKeys) {
        final queryValue = uri.queryParameters[key]?.trim();
        if (queryValue != null && queryValue.isNotEmpty) return cleanCode(queryValue);
      }

      final pathSegments = uri.pathSegments.where((segment) => segment.trim().isNotEmpty).toList();
      if (pathSegments.isNotEmpty) {
        return cleanCode(pathSegments.last);
      }
    }

    return cleanCode(value);
  }

  String cleanCode(String value) {
    return value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(
        title: Text(text.isKy ? 'QR сканер' : 'QR сканер'),
        actions: [
          IconButton(
            tooltip: text.isKy ? 'Жарык' : 'Фонарик',
            onPressed: () => controller.toggleTorch(),
            icon: const Icon(Icons.flashlight_on_rounded),
          ),
          IconButton(
            tooltip: text.isKy ? 'Камераны алмаштыруу' : 'Сменить камеру',
            onPressed: () => controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: handleDetect,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: MobileChatTheme.primary, width: 4),
                ),
                child: Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface.withOpacity(0.92),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    text.isKy ? 'Топтун QR кодун камерага көрсөтүңүз.' : 'Наведите камеру на QR код группы.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textStrong, fontWeight: FontWeight.w800),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    ErrorBanner(message: error!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
