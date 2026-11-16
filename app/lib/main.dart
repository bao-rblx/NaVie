import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/planner/planner_screen.dart';
import 'features/settings/settings_screen.dart';
import 'l10n/app_localizations.dart';

void main() => runApp(const ProviderScope(child: NaVieApp()));

final _router = GoRouter(routes: [
  GoRoute(path: '/', builder: (context, state) => const PlannerScreen()),
  GoRoute(
      path: '/settings', builder: (context, state) => const SettingsScreen()),
]);

class NaVieApp extends ConsumerWidget {
  const NaVieApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'NaVie',
        locale: ref.watch(localeProvider),
        themeMode: ref.watch(themeProvider),
        darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xff087f5b),
                brightness: Brightness.dark),
            useMaterial3: true),
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff087f5b)),
          scaffoldBackgroundColor: const Color(0xfff7f9f7),
          useMaterial3: true,
          filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
            minimumSize: const Size(48, 52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          )),
          outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          )),
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: _router,
      );
}
