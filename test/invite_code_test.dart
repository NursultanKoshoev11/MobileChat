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

    test('accepts plain 6 and 12 character codes', () {
      expect(extractInviteCode('abc234', baseUrl: base), 'ABC234');
      expect(extractInviteCode('ABC-234', baseUrl: base), 'ABC234');
      expect(extractInviteCode('abc-def-234-567', baseUrl: base),
          'ABCDEF234567');
    });

    test('rejects plain codes of other shapes', () {
      for (final value in [
        'ABC23',
        'ABC2345',
        'ABCDEFGHIJK',
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

    test('formats up to 12 characters in groups of three', () {
      expect(formatGroupInviteCode('abcdefg'), 'ABC-DEF-G');
      expect(formatGroupInviteCode('abcdef234567'), 'ABC-DEF-234-567');
      expect(formatGroupInviteCode('abcdef2345678999'), 'ABC-DEF-234-567');
    });

    test('formatter allows typing a 12-character code', () {
      final formatter = GroupInviteCodeFormatter();
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: 'abcdef234567'),
      );
      expect(result.text, 'ABC-DEF-234-567');
      expect(result.selection.baseOffset, result.text.length);
    });
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
