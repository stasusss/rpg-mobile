import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_locale.dart';
import '../l10n/l10n.dart';
import 'settings_provider.dart';

/// Language state. Persists through [settingsProvider] so a restart keeps it.
class LocaleNotifier extends Notifier<AppLocale> {
  @override
  AppLocale build() => ref.watch(settingsProvider.select((s) => s.locale));

  void setLocale(AppLocale locale) =>
      ref.read(settingsProvider.notifier).setLocale(locale);
}

final localeProvider = NotifierProvider<LocaleNotifier, AppLocale>(
  LocaleNotifier.new,
);

/// Dictionary bound to the current language. Watch this so chrome rebuilds.
final l10nProvider = Provider<L10n>((ref) => L10n(ref.watch(localeProvider)));
