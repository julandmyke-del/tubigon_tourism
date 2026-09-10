import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/routes/app_router.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/reconnect_sync_coordinator.dart';
import 'database/database_helper.dart';
import 'core/localization/app_localization.dart';
import 'core/widgets/offline_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize local storage
  await LocalStorageService.init();

  // Initialize SQLite database (not supported on web)
  if (DatabaseHelper.isSupported) {
    await DatabaseHelper.instance.database;
  }

  runApp(
    const ProviderScope(
      child: TubigonApp(),
    ),
  );
}

class TubigonApp extends ConsumerWidget {
  const TubigonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    ref.watch(reconnectSyncCoordinatorProvider);
    final themeAsync = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    final themeMode = themeAsync.when(
      data: (mode) => mode,
      loading: () => ThemeMode.system,
      error: (_, __) => ThemeMode.system,
    );

    return MaterialApp.router(
      title: 'Tour Tubigon',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,

      // Router
      routerConfig: router,
      builder: (context, child) => Stack(
        children: [
          if (child != null) child,
          const Positioned(top: 0, left: 0, right: 0, child: OfflineBanner()),
        ],
      ),

      // Localization
      localizationsDelegates: const [
        CebuanoMaterialLocalizationsDelegate(),
        CebuanoWidgetsLocalizationsDelegate(),
        CebuanoCupertinoLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('fil'),
        Locale('ceb'),
      ],
      locale: locale,
    );
  }
}
