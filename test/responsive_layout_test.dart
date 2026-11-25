import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koom/app/appearance.dart';
import 'package:koom/app/localization.dart';
import 'package:koom/app/theme.dart';
import 'package:koom/data/api_client.dart';
import 'package:koom/data/public_request.dart';
import 'package:koom/data/session_store.dart';
import 'package:koom/features/auth/phone_auth_screen.dart';
import 'package:koom/features/public_requests/public_request_media_screens.dart';
import 'package:koom/shared/koom_ui.dart';

class _SilentAuthApi extends ApiClient {
  _SilentAuthApi()
      : super(
          baseUrl: 'https://koom.example',
          sessionStore: const SessionStore(),
        );

  @override
  Future<RequestCodeResult> requestPhoneCode(String mobile) async =>
      RequestCodeResult.fromJson({'status': 'code_sent'});
}

Future<void> pumpAtSize(
  WidgetTester tester,
  Size size,
  Widget child, {
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: KoomTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('responsive action buttons stack on narrow screens',
      (tester) async {
    await pumpAtSize(
      tester,
      const Size(320, 568),
      Padding(
        padding: const EdgeInsets.all(16),
        child: KoomResponsiveActions(
          children: [
            OutlinedButton(
              key: const ValueKey('first_action'),
              onPressed: () {},
              child: const Text('First action'),
            ),
            FilledButton(
              key: const ValueKey('second_action'),
              onPressed: () {},
              child: const Text('Second action'),
            ),
          ],
        ),
      ),
    );

    final first = tester.getRect(find.byKey(const ValueKey('first_action')));
    final second = tester.getRect(find.byKey(const ValueKey('second_action')));
    expect(second.top, greaterThan(first.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('responsive action buttons stay in one row on wide screens',
      (tester) async {
    await pumpAtSize(
      tester,
      const Size(700, 900),
      Padding(
        padding: const EdgeInsets.all(16),
        child: KoomResponsiveActions(
          children: [
            OutlinedButton(
              key: const ValueKey('first_action'),
              onPressed: () {},
              child: const Text('First action'),
            ),
            FilledButton(
              key: const ValueKey('second_action'),
              onPressed: () {},
              child: const Text('Second action'),
            ),
          ],
        ),
      ),
    );

    final first = tester.getRect(find.byKey(const ValueKey('first_action')));
    final second = tester.getRect(find.byKey(const ValueKey('second_action')));
    expect(second.left, greaterThan(first.right));
    expect((second.center.dy - first.center.dy).abs(), lessThan(0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('adaptive tile grid wraps without overlap on narrow screens',
      (tester) async {
    await pumpAtSize(
      tester,
      const Size(320, 568),
      Padding(
        padding: const EdgeInsets.all(12),
        child: KoomAdaptiveTileGrid(
          children: List.generate(
            4,
            (index) => SizedBox(
              key: ValueKey('tile_$index'),
              height: 64,
              child: Text('Tile $index'),
            ),
          ),
        ),
      ),
    );

    final first = tester.getRect(find.byKey(const ValueKey('tile_0')));
    final second = tester.getRect(find.byKey(const ValueKey('tile_1')));
    final third = tester.getRect(find.byKey(const ValueKey('tile_2')));
    expect(second.left, greaterThan(first.left));
    expect(third.top, greaterThan(first.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('adaptive tile grid uses one row when width allows it',
      (tester) async {
    await pumpAtSize(
      tester,
      const Size(700, 900),
      Padding(
        padding: const EdgeInsets.all(12),
        child: KoomAdaptiveTileGrid(
          children: List.generate(
            4,
            (index) => SizedBox(
              key: ValueKey('tile_$index'),
              height: 64,
              child: Text('Tile $index'),
            ),
          ),
        ),
      ),
    );

    final first = tester.getRect(find.byKey(const ValueKey('tile_0')));
    final fourth = tester.getRect(find.byKey(const ValueKey('tile_3')));
    expect(fourth.top, first.top);
    expect(fourth.left, greaterThan(first.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('adaptive FAB hides its label on compact screens',
      (tester) async {
    await pumpAtSize(
      tester,
      const Size(320, 568),
      KoomAdaptiveFab(
        onPressed: () {},
        icon: Icons.add_rounded,
        label: 'Create a new community',
      ),
    );

    expect(find.text('Create a new community'), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adaptive FAB shows its label on wide screens',
      (tester) async {
    await pumpAtSize(
      tester,
      const Size(700, 900),
      KoomAdaptiveFab(
        onPressed: () {},
        icon: Icons.add_rounded,
        label: 'Create a new community',
      ),
    );

    expect(find.text('Create a new community'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings sheet has no overflow on a small phone',
      (tester) async {
    final appearance = AppAppearanceController();
    final language = AppLanguageController();
    await tester.binding.setSurfaceSize(const Size(280, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      AppAppearanceScope(
        controller: appearance,
        child: AppLanguageScope(
          controller: language,
          child: MaterialApp(
            theme: KoomTheme.light,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(280, 520),
                textScaler: TextScaler.linear(1.35),
              ),
              child: const Scaffold(body: AppSettingsSheet()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppSettingsSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long status labels stay inside a narrow viewport',
      (tester) async {
    await pumpAtSize(
      tester,
      const Size(280, 520),
      const Center(
        child: KoomStatusPill(
          icon: Icons.verified_user_outlined,
          label:
              'A very long status label that must never overflow the screen',
        ),
      ),
    );

    final rect = tester.getRect(find.byType(KoomStatusPill));
    expect(rect.width, lessThanOrEqualTo(280));
    expect(tester.takeException(), isNull);
  });

  // The sign-in screen is the one screen every user sees, and the first one
  // they see at their own text size. Kyrgyz labels run longer than the
  // Russian, so both languages are checked on a 320dp phone at scale 1.35,
  // on the phone step and on the code step.
  group('sign-in screen fits a small phone at a large text size', () {
    const size = Size(320, 568);

    for (final language in AppLanguage.values) {
      for (final onCodeStep in const [false, true]) {
        final label = '${language.name} '
            '${onCodeStep ? 'code step' : 'phone step'}';
        testWidgets('$label stays inside the viewport', (tester) async {
          FlutterSecureStorage.setMockInitialValues({});
          final controller = AppLanguageController();
          controller.setLanguage(language);
          addTearDown(controller.dispose);

          await pumpAtSize(
            tester,
            size,
            AppAppearanceScope(
              controller: AppAppearanceController(),
              child: AppLanguageScope(
                controller: controller,
                child: PhoneAuthScreen(
                  api: _SilentAuthApi(),
                  onAuthenticated: (_) async {},
                ),
              ),
            ),
            textScale: 1.35,
          );

          if (onCodeStep) {
            await tester.enterText(
              find.byKey(const ValueKey('auth_mobile_field')),
              '700123456',
            );
            await tester.pump();
            final terms = find.byKey(const ValueKey('terms_accept_checkbox'));
            await tester.ensureVisible(terms);
            await tester.tap(terms);
            await tester.pump();
            final submit = find.byKey(const ValueKey('auth_submit_button'));
            await tester.ensureVisible(submit);
            await tester.tap(submit);
            await tester.pumpAndSettle();
            expect(find.byKey(const ValueKey('auth_code_field')),
                findsOneWidget);
          }

          expect(tester.takeException(), isNull);
          // Nothing may be laid out past either screen edge, which catches a
          // RenderFlex that clipped silently instead of throwing.
          for (final element in find.byType(Text).evaluate()) {
            final rect = tester.getRect(find.byElementPredicate(
              (candidate) => candidate == element,
            ));
            expect(
              rect.right,
              lessThanOrEqualTo(size.width + 0.5),
              reason: 'overflow in ${(element.widget as Text).data}',
            );
            expect(rect.left, greaterThanOrEqualTo(-0.5));
          }
        });
      }
    }
  });

  // The post card footer carries the vote total next to the comment link. Both
  // halves must give way instead of claiming their natural width: Kyrgyz
  // labels run longer than the Russian, and these users are on small phones.
  group('post card footer never overflows', () {
    PublicRequest footerRequest({String interactionMode = 'discussion'}) {
      return PublicRequest.fromJson({
        'id': 'REQ-NARROW',
        'group_id': 'G-1',
        'author_id': 'U-1',
        'author_name': 'Нурсултан Кошоев',
        'request_type': 'announcement',
        'interaction_mode': interactionMode,
        'title': 'Детская площадка во дворе нашего дома',
        'body': 'Нужна новая площадка.',
        'status': 'under_review',
        'support_count': 128,
        'oppose_count': 64,
        'comment_count': 256,
        'created_at': '2026-11-20T00:00:00Z',
        'updated_at': '2026-11-20T00:00:00Z',
      });
    }

    // 360dp at scale 1.0 is the common phone for these users; the two
    // smaller sizes at 1.35 are the accessibility worst case.
    const probes = <(Size, double)>[
      (Size(360, 640), 1),
      (Size(320, 568), 1.35),
      (Size(280, 520), 1.35),
    ];
    for (final (size, scale) in probes) {
      for (final language in AppLanguage.values) {
        // showOpenAction true is the feed card (comment link); false is the
        // detail card, where the footer is entirely new.
        for (final showOpenAction in const [true, false]) {
          final label = 'card ${size.width.toInt()}dp x$scale '
              '${language.name} '
              '${showOpenAction ? 'feed' : 'detail'}';
          testWidgets('$label stays inside the viewport', (tester) async {
            final controller = AppLanguageController();
            controller.setLanguage(language);
            addTearDown(controller.dispose);

            await pumpAtSize(
              tester,
              size,
              AppLanguageScope(
                controller: controller,
                child: SingleChildScrollView(
                  child: MediaPublicRequestCard(
                    request: footerRequest(),
                    onTap: () {},
                    onVote: (_) {},
                    canModerate: true,
                    onStatus: (_) {},
                    compact: showOpenAction,
                    showOpenAction: showOpenAction,
                  ),
                ),
              ),
              textScale: scale,
            );

            expect(tester.takeException(), isNull);
            final card = tester.getRect(
              find.byType(MediaPublicRequestCard),
            );
            expect(card.width, lessThanOrEqualTo(size.width));
            // Every Text on the card must fit the screen too, which catches a
            // RenderFlex that silently clipped instead of throwing.
            for (final element in find.byType(Text).evaluate()) {
              final rect = tester.getRect(find.byElementPredicate(
                (candidate) => candidate == element,
              ));
              expect(
                rect.right,
                lessThanOrEqualTo(size.width + 0.5),
                reason: 'overflow in ${(element.widget as Text).data}',
              );
              expect(rect.left, greaterThanOrEqualTo(-0.5));
            }
          });
        }

        testWidgets(
            'read-only card ${size.width.toInt()}dp x$scale '
            '${language.name} stays inside the viewport', (tester) async {
          final controller = AppLanguageController();
          controller.setLanguage(language);
          addTearDown(controller.dispose);

          await pumpAtSize(
            tester,
            size,
            AppLanguageScope(
              controller: controller,
              child: SingleChildScrollView(
                child: MediaPublicRequestCard(
                  request: footerRequest(interactionMode: 'read_only'),
                  onTap: () {},
                  onVote: (_) {},
                ),
              ),
            ),
            textScale: scale,
          );

          expect(tester.takeException(), isNull);
          expect(
            tester.getRect(find.byType(MediaPublicRequestCard)).width,
            lessThanOrEqualTo(size.width),
          );
        });
      }
    }
  });
}
