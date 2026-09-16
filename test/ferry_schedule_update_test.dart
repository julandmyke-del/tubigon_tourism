import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/core/network/connectivity_provider.dart';
import 'package:tubigon_tourism/features/ferry/models/ferry.dart';
import 'package:tubigon_tourism/features/ferry/repositories/ferry_repository.dart';
import 'package:tubigon_tourism/features/userpage/presentation/pages/ferry_schedule_page.dart';

void main() {
  const operators = [
    FerryOperator(
      id: 'lite',
      name: 'Lite Ferries',
      vessels: [FerryVessel(id: 'lite-17', name: 'Lite Ferry 17')],
    ),
    FerryOperator(id: 'fastcat', name: 'FastCat'),
    FerryOperator(
      id: 'starcraft',
      name: 'MV Starcraft',
      vessels: [FerryVessel(id: 'sc2', name: 'SC 2')],
    ),
  ];

  final schedules = [
    Ferry(
      id: 1,
      uuid: 'lite-1',
      operatorId: 'lite',
      operator: 'Lite Ferries',
      vesselId: 'lite-17',
      vessel: 'Lite Ferry 17',
      route: 'Cebu to Tubigon',
      origin: 'Cebu Port',
      destination: 'Tubigon Port',
      departure: '00:30',
      arrival: null,
      duration: 'Duration unavailable',
      fare: null,
      status: 'scheduled',
      days: [],
      effectiveFrom: DateTime(2026, 8, 15),
    ),
    const Ferry(
      id: 2,
      uuid: 'fastcat-1',
      operatorId: 'fastcat',
      operator: 'FastCat',
      route: 'Tubigon to Cebu',
      origin: 'Tubigon Port',
      destination: 'Cebu Port',
      departure: '22:30',
      arrival: '00:30',
      arrivalNextDay: true,
      duration: '2h 00m',
      fare: null,
      status: 'scheduled',
      days: [],
    ),
  ];

  Widget app({
    required Future<List<Ferry>> Function(Ref ref) scheduleOverride,
  }) {
    return ProviderScope(
      key: UniqueKey(),
      overrides: [
        isOnlineProvider.overrideWithValue(true),
        ferryOperatorsProvider.overrideWith((ref) async => operators),
        ferrySchedulesListProvider.overrideWith(scheduleOverride),
      ],
      child: const MaterialApp(
        home: FerrySchedulePage(),
      ),
    );
  }

  testWidgets(
      'All groups schedules by operator and route with safe time labels',
      (tester) async {
    await tester.pumpWidget(app(scheduleOverride: (ref) async => schedules));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Lite Ferries'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'FastCat'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'MV Starcraft'), findsOneWidget);
    expect(find.text('Cebu Port → Tubigon Port'), findsOneWidget);
    expect(find.text('Tubigon Port → Cebu Port'), findsOneWidget);
    expect(find.text('Not provided'), findsOneWidget);
    expect(find.textContaining('Next Day'), findsOneWidget);
    expect(
        find.textContaining('Effective from August 15, 2026'), findsOneWidget);
    expect(find.textContaining('Ferry schedules may change'), findsOneWidget);
  });

  testWidgets('individual operator filter hides other operator schedules',
      (tester) async {
    await tester.pumpWidget(app(scheduleOverride: (ref) async => schedules));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'FastCat'));
    await tester.pumpAndSettle();

    expect(find.textContaining('10:30'), findsOneWidget);
    expect(find.textContaining('Next Day'), findsOneWidget);
    expect(find.text('Lite Ferry 17'), findsNothing);
  });

  testWidgets('operator chips remain scrollable on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(scheduleOverride: (ref) async => schedules));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('empty and error states are explicit and retryable',
      (tester) async {
    await tester.pumpWidget(app(scheduleOverride: (ref) async => const []));
    await tester.pumpAndSettle();
    expect(find.text('Schedule information is being updated.'), findsOneWidget);

    await tester.pumpWidget(app(
      scheduleOverride: (ref) async => throw Exception('network failed'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ferry schedules could not be loaded'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
  });
}
