import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/generated/core_localizations.dart';

/// Sudan is UTC+2 all year (no daylight saving); times are stored in UTC.
const khartoumOffset = Duration(hours: 2);

DateTime toKhartoum(DateTime t) => t.toUtc().add(khartoumOffset);

/// Western digits (0–9) in both languages: they match Bankak receipts and the
/// order reference people type into the Bankak note (D-048).
final _grouped = NumberFormat('#,##0', 'en');

String groupDigits(int value) => _grouped.format(value);

DateFormat _date(String pattern, Locale locale) =>
    DateFormat(pattern, locale.languageCode)..useNativeDigits = false;

extension AppFormatting on BuildContext {
  Locale get _locale => Localizations.localeOf(this);

  /// "12,000 ج.س" / "SDG 12,000".
  String sdg(int amount) => CoreLocalizations.of(this).money(groupDigits(amount));

  /// "4:30 م" / "4:30 PM", Khartoum time.
  String time(DateTime t) => _date('h:mm a', _locale).format(toKhartoum(t));

  /// "الخميس 16 أكتوبر" / "Thu 16 Oct".
  String day(DateTime t) => _date(
    _locale.languageCode == 'ar' ? 'EEEE d MMMM' : 'EEE d MMM',
    _locale,
  ).format(toKhartoum(t));

  /// "16 أكتوبر 2026" / "16 Oct 2026".
  String date(DateTime t) => _date('d MMM y', _locale).format(toKhartoum(t));

  /// "الخميس 16 أكتوبر · 4:30 م".
  String dayTime(DateTime t) => '${day(t)} · ${time(t)}';

  /// Short weekday ("الخميس" / "Thu") and day of month, for date chips.
  String weekday(DateTime t) => _date('EEEE', _locale).format(toKhartoum(t));

  String dayOfMonth(DateTime t) => _date('d MMM', _locale).format(toKhartoum(t));
}

/// "4815 1627": an 8-digit order reference, grouped for reading aloud and typing.
/// Isolated left-to-right so the two groups never swap places in Arabic.
String formatRef(String ref) =>
    ref.length == 8 ? ltr('${ref.substring(0, 4)} ${ref.substring(4)}') : ref;

/// Wraps [s] in a left-to-right isolate (LRI…PDI): number ranges such as
/// "6,000–7,000" otherwise render reversed inside right-to-left text.
String ltr(String s) => '$_lri$s$_pdi';

/// Wraps user text (a person's name in Arabic or Latin) in a first-strong
/// isolate, so its own punctuation stays with it inside a sentence in the
/// other language ("From أحمد م." keeps the dot after the name).
String isolate(String s) => '$_fsi$s$_pdi';

final _lri = String.fromCharCode(0x2066);
final _fsi = String.fromCharCode(0x2068);
final _pdi = String.fromCharCode(0x2069);

/// "9:32" or "1:05:09" from a duration, for hold and payment countdowns.
String clockText(Duration d) {
  if (d.isNegative) return '0:00';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
