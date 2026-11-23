import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koom/app/app.dart';
import 'package:koom/app/localization.dart';

void main() {
  group('combineTextScalers', () {
    test('multiplies the system scale by the app scale', () {
      expect(
        combineTextScalers(TextScaler.linear(1.3), 1.15).scale(10),
        closeTo(14.95, 0.001),
      );
      expect(combineTextScalers(TextScaler.noScaling, 0.9).scale(10),
          closeTo(9, 0.001));
    });

    test('clamps very large accessibility sizes to $kMaxTextScale', () {
      expect(combineTextScalers(TextScaler.linear(3), 1.15).scale(10),
          closeTo(10 * kMaxTextScale, 0.001));
    });
  });

  for (final language in AppLanguage.values) {
    testWidgets('Material/Cupertino localizations load for ${language.name}',
        (tester) async {
      late MaterialLocalizations material;
      late CupertinoLocalizations cupertino;
      await tester.pumpWidget(MaterialApp(
        locale: materialLocaleFor(language),
        supportedLocales: kSupportedLocales,
        localizationsDelegates: kLocalizationsDelegates,
        home: Builder(builder: (context) {
          material = MaterialLocalizations.of(context);
          cupertino = CupertinoLocalizations.of(context);
          return const SizedBox();
        }),
      ));
      await tester.pumpAndSettle();
      expect(Localizations.localeOf(tester.element(find.byType(SizedBox))),
          materialLocaleFor(language));
      expect(material.cancelButtonLabel, isNot('Cancel'));
      expect(cupertino.selectAllButtonLabel, isNot('Select All'));
    });
  }
}
