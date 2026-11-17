/// The profile choices as the backend stores them.
///
/// The web app and this app grew different words for the same options
/// ("light" / "low", "warm" / "tropical", "minus" / "weight"), so an account
/// edited on the website showed raw keys here and the reverse. The web's
/// words are canonical; the old ones are still read (and folded into the new
/// ones) so existing accounts keep working.
class ProfileVocabulary {
  ProfileVocabulary._();

  static const activity = [
    'sedentary',
    'light',
    'moderate',
    'active',
    'intense',
  ];
  static const climate = ['cold', 'temperate', 'warm', 'hot'];
  static const goal = ['minus', 'norm', 'plus'];

  static const _aliases = <String, Map<String, String>>{
    'activity_level': {'low': 'light', 'high': 'active', 'athlete': 'intense'},
    'climate_type': {'tropical': 'hot'},
    'goal': {'weight': 'minus', 'wellbeing': 'norm', 'routine': 'norm'},
  };

  /// [value] in the canonical spelling, or [fallback] when it is missing.
  static String normalize(String field, String? value, String fallback) {
    if (value == null || value.isEmpty) return fallback;
    return _aliases[field]?[value] ?? value;
  }
}
