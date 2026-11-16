import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

final localeProvider = StateProvider<Locale>((ref) => const Locale('vi'));
final themeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Language and appearance preferences for the current app session.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Text(l.makeItYours, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 12),
        Text(l.settingsSubtitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(l.language),
          trailing: DropdownButton<String>(
            value: ref.watch(localeProvider).languageCode,
            items: const [
              DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
              DropdownMenuItem(value: 'en', child: Text('English'))
            ],
            onChanged: (value) =>
                ref.read(localeProvider.notifier).state = Locale(value!),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.dark_mode_outlined),
          title: Text(l.appearance),
          trailing: DropdownButton<ThemeMode>(
              value: ref.watch(themeProvider),
              items: [
                DropdownMenuItem(
                    value: ThemeMode.system, child: Text(l.systemTheme)),
                DropdownMenuItem(
                    value: ThemeMode.light, child: Text(l.dayTheme)),
                DropdownMenuItem(
                    value: ThemeMode.dark, child: Text(l.nightTheme)),
              ],
              onChanged: (value) =>
                  ref.read(themeProvider.notifier).state = value!),
        ),
        const SizedBox(height: 24),
        Text(l.appLimitations, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 24),
        Text(l.osmAttribution, style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
