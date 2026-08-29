/// Supported UI languages. Codes are what we persist in the save blob.
enum AppLocale {
  en,
  uk;

  String get code => name;

  String get nativeLabel => switch (this) {
    AppLocale.en => 'English',
    AppLocale.uk => 'Українська',
  };

  static AppLocale fromCode(String? code) => switch (code) {
    'uk' => AppLocale.uk,
    _ => AppLocale.en,
  };
}
