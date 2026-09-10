import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/core/localization/app_localization.dart';
import 'package:tubigon_tourism/core/localization/ceb.dart';
import 'package:tubigon_tourism/core/localization/en.dart';
import 'package:tubigon_tourism/core/localization/fil.dart';

void main() {
  test('all supported languages expose every localization key', () {
    expect(filStrings.keys.toSet(), enStrings.keys.toSet());
    expect(cebStrings.keys.toSet(), enStrings.keys.toSet());
    expect(filStrings['concerns_support'], 'Mga Alalahanin at Suporta');
    expect(cebStrings['offline_maps'], 'Offline nga mga Mapa');
  });

  test('device Filipino and Cebuano locales resolve without a preference', () {
    expect(LocaleController(const Locale('fil')).state.languageCode, 'fil');
    expect(LocaleController(const Locale('tl')).state.languageCode, 'fil');
    expect(LocaleController(const Locale('ceb')).state.languageCode, 'ceb');
    expect(LocaleController(const Locale('ja')).state.languageCode, 'en');
  });

  testWidgets('Cebuano locale resolves app and framework localizations',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ceb'),
      supportedLocales: const [Locale('en'), Locale('fil'), Locale('ceb')],
      localizationsDelegates: const [
        CebuanoMaterialLocalizationsDelegate(),
        CebuanoWidgetsLocalizationsDelegate(),
        CebuanoCupertinoLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(builder: (context) {
        expect(MaterialLocalizations.of(context), isNotNull);
        return Text(context.tr('carbon_estimator'));
      }),
    ));

    expect(find.text('Banabana sa Carbon Footprint'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
