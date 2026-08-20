import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the four locale files against drift. `.tr()` silently falls back to
/// the key, so a missing translation ships as English instead of failing.
void main() {
  const locales = ['en', 'de', 'ru', 'uk'];

  final translations = {
    for (final locale in locales)
      locale:
          (jsonDecode(File('assets/i18n/$locale.json').readAsStringSync())
              as Map<String, dynamic>),
  };

  test('every locale defines the same keys', () {
    final reference = translations['en']!.keys.toSet();
    for (final locale in locales.skip(1)) {
      expect(
        translations[locale]!.keys.toSet(),
        reference,
        reason: '$locale.json has drifted from en.json',
      );
    }
  });

  test('no translation is blank', () {
    for (final entry in translations.entries) {
      for (final pair in entry.value.entries) {
        expect(
          (pair.value as String).trim(),
          isNotEmpty,
          reason: '${entry.key}.json has an empty value for "${pair.key}"',
        );
      }
    }
  });

  test('en.json is the identity map the .tr() keys assume', () {
    translations['en']!.forEach((key, value) {
      expect(value, key, reason: 'en.json should map "$key" to itself');
    });
  });

  test('every literal .tr() key in lib/ is translated', () {
    // Matches both call styles: 'Some text'.tr( and context.tr('Some text').
    // Dynamic keys (drink names, achievement titles that come from the API)
    // are out of reach and checked at runtime instead.
    final patterns = [
      RegExp(r"'((?:[^'\\]|\\.)*)'\s*\.tr\("),
      RegExp(r"context\.tr\(\s*'((?:[^'\\]|\\.)*)'"),
    ];
    final used = <String>{};
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final pattern in patterns) {
        for (final match in pattern.allMatches(source)) {
          used.add(match.group(1)!.replaceAll(r"\'", "'"));
        }
      }
    }

    expect(used, isNotEmpty, reason: 'the scan found no keys at all');
    expect(
      used.difference(translations['en']!.keys.toSet()),
      isEmpty,
      reason: 'these keys are used in lib/ but missing from the locale files',
    );
  });

  test('no translated string is used as a bare literal', () {
    // The mirror of the test above, and the one that actually bites: a
    // string that *is* translated but ships without .tr() renders English
    // in every locale, silently. Error messages assigned to `_error` in
    // the providers were doing exactly this.
    //
    // Keys resolved from API data (drink names, achievement titles) never
    // appear as literals in lib/, so they can't trip this.
    // Values that legitimately stay English in source.
    const allowed = {
      // Persisted through Reminder.toJson, so translating it at parse time
      // would write the current locale's text into the database. The two
      // display sites in reminders_screen.dart do call .tr().
      'Time to drink water',
      // TableCalendar's format-button label, and formatButtonVisible is
      // false — this string is never rendered.
      'Month',
      // DrinkLog's name fallback when the API sends neither drink_name nor
      // a nested drink. It is a key, so the display sites that render it
      // through context.tr(log.drinkName) still translate it.
      'Drink',
    };

    final literal = RegExp(r"'((?:[^'\\]|\\.)*)'");
    final keys = translations['en']!.keys.toSet();
    final offenders = <String>[];

    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      // Comments are blanked rather than scanned: an apostrophe in prose
      // ("the dashboard's shape") would otherwise desync quote pairing for
      // the rest of the file and silently hide every later literal.
      final lines = [
        for (final line in file.readAsLinesSync())
          line.trimLeft().startsWith('//') ? '' : line,
      ];

      for (var i = 0; i < lines.length; i++) {
        for (final match in literal.allMatches(lines[i])) {
          final value = match.group(1)!.replaceAll(r"\'", "'");
          if (!keys.contains(value) || allowed.contains(value)) continue;

          // dart format often pushes .tr() onto the next line, so look
          // past the end of this one before calling it untranslated.
          final after =
              (lines[i].substring(match.end) +
                      (i + 1 < lines.length ? lines[i + 1] : ''))
                  .trimLeft();
          if (after.startsWith('.tr(')) continue;

          // Look back a line too, for the context.tr(\n 'Key',\n namedArgs:
          // shape the formatter produces for calls with arguments.
          final before =
              ((i > 0 ? lines[i - 1] : '') + lines[i].substring(0, match.start))
                  .trimRight();
          // context.tr('Key') / 'Key'.tr() are both fine; json['key'] is a
          // map subscript that only looks like a translation key.
          if (before.endsWith('tr(') || before.endsWith('[')) continue;

          offenders.add('${file.path}:${i + 1}  "$value"');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'these strings have translations but are used untranslated:\n'
          '${offenders.join('\n')}',
    );
  });
}
