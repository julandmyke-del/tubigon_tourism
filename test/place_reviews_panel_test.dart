import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/features/authentication/auth_provider.dart';
import 'package:tubigon_tourism/features/settings/repositories/settings_repository.dart';
import 'package:tubigon_tourism/features/tourist_spots/repositories/review_repository.dart';
import 'package:tubigon_tourism/features/userpage/presentation/widgets/place_reviews_panel.dart';

class _LoggedInTouristNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        isLoggedIn: true,
        role: UserRole.tourist,
        userId: 'tourist-id',
        name: 'Test Tourist',
      );
}

class _FakeReviewRepository implements ReviewRepository {
  _FakeReviewRepository(this.result);

  final Future<bool> result;
  int submissions = 0;

  @override
  Future<bool> addReview({
    required String reviewableType,
    required String reviewableId,
    required double rating,
    required String content,
  }) {
    submissions++;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(_FakeReviewRepository repository,
    {VoidCallback? onSaved, bool reviewsEnabled = true}) {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(_LoggedInTouristNotifier.new),
      reviewRepositoryProvider.overrideWithValue(repository),
      systemSettingsProvider
          .overrideWith((_) async => {'reviews_enabled': reviewsEnabled}),
      spotReviewsProvider(('msme', 'msme-id'))
          .overrideWith((ref) async => const []),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PlaceReviewsPanel(
            reviewableType: 'msme',
            reviewableId: 'msme-id',
            targetName: 'BAZAK Food Park',
            onReviewSaved: onSaved,
          ),
        ),
      ),
    ),
  );
}

Future<void> _openAndFill(WidgetTester tester) async {
  await tester.tap(find.text('Write a Review'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'Excellent local service.');
}

void main() {
  testWidgets('disabled global review setting disables the compose action',
      (tester) async {
    final repository = _FakeReviewRepository(Future.value(true));
    await tester.pumpWidget(_app(repository, reviewsEnabled: false));
    await tester.pumpAndSettle();

    final action =
        tester.widget<TextButton>(find.byKey(const Key('write-review-action')));
    expect(action.onPressed, isNull);
    expect(find.text('Reviews Disabled'), findsOneWidget);
    expect(repository.submissions, 0);
  });

  testWidgets('successful review prevents double submit and refreshes target',
      (tester) async {
    final pending = Completer<bool>();
    final repository = _FakeReviewRepository(pending.future);
    var refreshes = 0;
    await tester.pumpWidget(_app(repository, onSaved: () => refreshes++));
    await tester.pumpAndSettle();
    await _openAndFill(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pump();
    expect(repository.submissions, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);

    pending.complete(true);
    await tester.pumpAndSettle();
    expect(repository.submissions, 1);
    expect(refreshes, 1);
    expect(find.text('Review submitted successfully.'), findsOneWidget);
  });

  testWidgets('failed review stays open and reports an accurate error',
      (tester) async {
    final pending = Completer<bool>();
    final repository = _FakeReviewRepository(pending.future);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await _openAndFill(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pump();
    pending.completeError(Exception('Server rejected review'));
    await tester.pumpAndSettle();

    expect(repository.submissions, 1);
    expect(find.text('Write a Review'), findsWidgets);
    expect(find.textContaining('Server rejected review'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
  });

  testWidgets('leaving a place review during submit is lifecycle safe',
      (tester) async {
    final pending = Completer<bool>();
    final repository = _FakeReviewRepository(pending.future);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await _openAndFill(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    pending.complete(true);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
