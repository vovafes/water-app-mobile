import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:water_app_mobile/models/profile_vocabulary.dart';

/// The web and mobile apps used different words for the same profile choices,
/// so an account edited on one showed raw keys on the other.
void main() {
  test('old mobile spellings read as the web ones', () {
    expect(
      ProfileVocabulary.normalize('activity_level', 'low', 'moderate'),
      'light',
    );
    expect(
      ProfileVocabulary.normalize('activity_level', 'high', 'moderate'),
      'active',
    );
    expect(
      ProfileVocabulary.normalize('activity_level', 'athlete', 'moderate'),
      'intense',
    );
    expect(
      ProfileVocabulary.normalize('climate_type', 'tropical', 'temperate'),
      'hot',
    );
    expect(ProfileVocabulary.normalize('goal', 'weight', 'norm'), 'minus');
    expect(ProfileVocabulary.normalize('goal', 'wellbeing', 'norm'), 'norm');
    expect(ProfileVocabulary.normalize('goal', 'routine', 'norm'), 'norm');
  });

  test('web spellings pass through untouched', () {
    expect(
      ProfileVocabulary.normalize('activity_level', 'sedentary', 'moderate'),
      'sedentary',
    );
    expect(
      ProfileVocabulary.normalize('climate_type', 'warm', 'temperate'),
      'warm',
    );
    expect(ProfileVocabulary.normalize('goal', 'plus', 'norm'), 'plus');
  });

  test('a missing value falls back', () {
    expect(
      ProfileVocabulary.normalize('activity_level', null, 'moderate'),
      'moderate',
    );
    expect(ProfileVocabulary.normalize('goal', '', 'norm'), 'norm');
  });

  test('every option has a label in the English file', () {
    final en =
        jsonDecode(File('assets/i18n/en.json').readAsStringSync())
            as Map<String, dynamic>;
    const labels = [
      'Sedentary',
      'Light',
      'Moderate',
      'Active',
      'Intense',
      'Cold',
      'Temperate',
      'Warm',
      'Hot',
      'Lose weight',
      'Stay fit',
      'Gain muscle',
    ];
    for (final label in labels) {
      expect(
        en.containsKey(label),
        isTrue,
        reason: '"$label" is missing from en.json',
      );
    }
  });
}
