import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koom/app/localization.dart';
import 'package:koom/features/groups/group_qr_scan_screen.dart';
import 'package:koom/features/groups/groups_screen.dart';

void main() {
  const base = 'https://api.koom.test';

  group('extractInviteCode', () {
    test('accepts signed INV1 tokens unchanged', () {
      expect(extractInviteCode('INV1.abc_DEF-123.sig', baseUrl: base),
          'INV1.abc_DEF-123.sig');
      expect(extractInviteCode('  INV1.token  ', baseUrl: base), 'INV1.token');
    });

    test('rejects malformed INV1 tokens', () {
      expect(extractInviteCode('INV1.', baseUrl: base), isNull);
      expect(extractInviteCode('INV1.<script>', baseUrl: base), isNull);
    });

    test('accepts legacy 6 and current 10 character codes', () {
      expect(extractInviteCode('abc234', baseUrl: base), 'ABC234');
      expect(extractInviteCode('ABC-234', baseUrl: base), 'ABC234');
      expect(extractInviteCode('K7M2P-QX9ZT', baseUrl: base), 'K7M2PQX9ZT');
      expect(extractInviteCode('k7m2pqx9zt', baseUrl: base), 'K7M2PQX9ZT');
      expect(
          extractInviteCode('https://koom.com.kg/join?code=K7M2P-QX9ZT',
              baseUrl: base),
          'K7M2PQX9ZT');
    });

    test('rejects plain codes of other shapes', () {
      for (final value in [
        'ABC23',
        'ABC2345',
        'ABCDEFGHIJK',
        'ABCDEFGHIJKL',
        'ABCDEFGHIJKLM',
        'ABC 234',
        'ABC_234',
        'АБВ234',
        'hello world',
        '',
      ]) {
        expect(extractInviteCode(value, baseUrl: base), isNull, reason: value);
      }
    });

    test('accepts links on koom.com.kg and the configured API host', () {
      expect(
          extractInviteCode('https://koom.com.kg/join?code=abc-234',
              baseUrl: base),
          'ABC234');
      expect(
          extractInviteCode('https://koom.com.kg/invite/ABC234',
              baseUrl: base),
          'ABC234');
      expect(
          extractInviteCode('https://api.koom.test/join?invite_code=INV1.tok',
              baseUrl: base),
          'INV1.tok');
    });

    test('rejects links on foreign hosts or with invalid codes', () {
      for (final value in [
        'https://evil.example/join?code=ABC234',
        'https://koom.com.kg.evil.example/join?code=ABC234',
        'https://koom.com.kg@evil.example/join?code=ABC234',
        'https://koom.com.kg/join?code=not-a-code!',
        'https://koom.com.kg/',
        'intent://koom.com.kg/ABC234',
        'javascript:alert(1)',
      ]) {
        expect(extractInviteCode(value, baseUrl: base), isNull, reason: value);
      }
    });
  });

  group('formatGroupInviteCode', () {
    test('keeps 6-character codes formatted as today', () {
      expect(formatGroupInviteCode('abc234'), 'ABC-234');
      expect(formatGroupInviteCode('ABC-234'), 'ABC-234');
      expect(formatGroupInviteCode('ab'), 'AB');
      expect(formatGroupInviteCode('abcd'), 'ABC-D');
    });

    test('formats new 10-character codes as XXXXX-XXXXX', () {
      expect(formatGroupInviteCode('k7m2pqx9zt'), 'K7M2P-QX9ZT');
      expect(formatGroupInviteCode('K7M2P-QX9ZT'), 'K7M2P-QX9ZT');
      expect(formatGroupInviteCode(' k7m2p qx9zt '), 'K7M2P-QX9ZT');
      expect(formatGroupInviteCode('k7m2p--qx9zt'), 'K7M2P-QX9ZT');
      expect(formatGroupInviteCode('abcdefg'), 'ABCDE-FG');
      expect(formatGroupInviteCode('K7M2PQX9ZTEXTRA'), 'K7M2P-QX9ZT');
      expect(formatGroupInviteCode('K7M2PQX9ZT').length,
          maxFormattedGroupInviteCodeLength);
    });

    test('formatter allows typing or pasting a new 10-character code', () {
      final formatter = GroupInviteCodeFormatter();
      final pasted = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: 'k7m2p qx9zt'),
      );
      expect(pasted.text, 'K7M2P-QX9ZT');
      expect(pasted.selection.baseOffset, pasted.text.length);

      var typed = TextEditingValue.empty;
      for (final char in 'k7m2pqx9zt'.split('')) {
        typed = formatter.formatEditUpdate(
          typed,
          TextEditingValue(text: typed.text + char),
        );
      }
      expect(typed.text, 'K7M2P-QX9ZT');
    });

    test('old codes still format as AAA-999', () {
      final formatter = GroupInviteCodeFormatter();
      var typed = TextEditingValue.empty;
      for (final char in 'abc234'.split('')) {
        typed = formatter.formatEditUpdate(
          typed,
          TextEditingValue(text: typed.text + char),
        );
      }
      expect(typed.text, 'ABC-234');
    });
  });

  group('decodeSignedInviteClaims', () {
    String token(Map<String, Object?> claims) {
      final payload =
          base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '');
      return 'INV1.$payload.signature';
    }

    test('reads group id, code and optional title', () {
      final claims = decodeSignedInviteClaims(token({
        'group_id': 'G-1',
        'invite_code': 'K7M2P-QX9ZT',
        'exp': 1,
        'group_title': 'Айыл кеңеши',
      }));
      expect(claims?.groupId, 'G-1');
      expect(claims?.inviteCode, 'K7M2P-QX9ZT');
      expect(claims?.groupTitle, 'Айыл кеңеши');
    });

    test('returns null for malformed tokens', () {
      expect(decodeSignedInviteClaims('INV1.%%%.sig'), isNull);
      expect(decodeSignedInviteClaims('ABC234'), isNull);
    });
  });

  testWidgets('scanned invite confirmation shows the group name',
      (tester) async {
    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => confirmJoinScannedInvite(context,
                  displayCode: 'K7M2P-QX9ZT', groupName: 'Наш двор'),
              child: const Text('scan'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('«Наш двор»'), findsOneWidget);
    expect(find.textContaining('K7M2P-QX9ZT'), findsOneWidget);
  });

  testWidgets('scanned invite requires confirmation before joining',
      (tester) async {
    bool? confirmed;
    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                confirmed = await confirmJoinScannedInvite(context,
                    displayCode: 'ABC-234');
              },
              child: const Text('scan'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
    expect(find.text('Вступить в группу?'), findsOneWidget);
    expect(find.textContaining('ABC-234'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(confirmed, isFalse);

    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Вступить'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });
}
