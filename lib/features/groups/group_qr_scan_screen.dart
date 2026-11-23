import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/api_config.dart';
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
                  border: Border.all(color: KoomTheme.primary, width: 4),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final available = constraints.maxWidth < constraints.maxHeight
                        ? constraints.maxWidth
                        : constraints.maxHeight;
                    final frameSize =
                        (available * 0.62).clamp(120.0, 260.0).toDouble();
                    return Center(
                      child: SizedBox(
                        width: frameSize,
                        height: frameSize,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 3),
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 4),
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
          ),
        ],
      ),
    );
  }
}

/// Hosts whose invite links the scanner accepts.
Set<String> trustedInviteHosts({String baseUrl = kApiBaseUrl}) {
  final hosts = <String>{'koom.com.kg'};
  final apiHost = Uri.tryParse(baseUrl)?.host.toLowerCase() ?? '';
  if (apiHost.isNotEmpty) hosts.add(apiHost);
  return hosts;
}

final RegExp _signedInvitePattern = RegExp(r'^INV1\.[A-Za-z0-9._~-]{1,512}$');
final RegExp _plainInviteCodePattern =
    RegExp(r'^(?:[A-Za-z0-9]{6}|[A-Za-z0-9]{10})$');
const _inviteQueryKeys = ['invite_code', 'inviteCode', 'code', 'group_code'];

/// Extracts a group invite code from a scanned QR payload. Accepts only:
/// * signed invite tokens starting with `INV1.`;
/// * http(s) links on koom.com.kg or the configured API host that carry the
///   code in a query parameter or as the last path segment;
/// * plain invite codes: 6 (legacy `AAA-999`) or 10 (`XXXXX-XXXXX`)
///   letters/digits once dashes are removed.
/// Anything else returns null.
String? extractInviteCode(String rawValue, {String baseUrl = kApiBaseUrl}) {
  final value = rawValue.trim();
  if (value.isEmpty || value.length > 2048) return null;

  final direct = _normalizeInviteCandidate(value);
  if (direct != null) return direct;

  final uri = Uri.tryParse(value);
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
    return null;
  }
  if (uri.userInfo.isNotEmpty) return null;
  if (!trustedInviteHosts(baseUrl: baseUrl).contains(uri.host.toLowerCase())) {
    return null;
  }
  for (final key in _inviteQueryKeys) {
    final queryValue = uri.queryParameters[key];
    if (queryValue != null && queryValue.trim().isNotEmpty) {
      return _normalizeInviteCandidate(queryValue);
    }
  }
  final segments =
      uri.pathSegments.where((segment) => segment.trim().isNotEmpty).toList();
  if (segments.isEmpty) return null;
  return _normalizeInviteCandidate(segments.last);
}

String? _normalizeInviteCandidate(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('INV1.')) {
    return _signedInvitePattern.hasMatch(trimmed) ? trimmed : null;
  }
  final compact = trimmed.replaceAll('-', '');
  if (!_plainInviteCodePattern.hasMatch(compact)) return null;
  return compact.toUpperCase();
}

/// Unverified claims of a signed `INV1.<payload>.<signature>` invite. Used
/// only to show the user what they are joining; the server verifies the
/// signature when joining.
class SignedInviteClaims {
  const SignedInviteClaims({this.groupId, this.inviteCode, this.groupTitle});

  final String? groupId;
  final String? inviteCode;
  final String? groupTitle;
}

SignedInviteClaims? decodeSignedInviteClaims(String token) {
  final parts = token.trim().split('.');
  if (parts.length != 3 || parts[0] != 'INV1') return null;
  try {
    final payload = base64Url.normalize(parts[1]);
    final decoded = jsonDecode(utf8.decode(base64Url.decode(payload)));
    if (decoded is! Map) return null;
    String? read(String key) {
      final value = decoded[key];
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return SignedInviteClaims(
      groupId: read('group_id'),
      inviteCode: read('invite_code'),
      groupTitle: read('group_title') ?? read('title'),
    );
  } catch (_) {
    return null;
  }
}
