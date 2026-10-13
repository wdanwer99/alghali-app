/// Client-side twin of the database's `ar_normalize()` (D-006): unifies alef,
/// taa-marbuta/yaa and Persian kaf/yaa spellings, turns Arabic-Indic digits into 0-9,
/// strips diacritics and tatweel, lower-cases Latin and collapses whitespace, so
/// "لمبة", "لمبه" and "لمبات" all match.
String arNormalize(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    if ((rune >= 0x064B && rune <= 0x0652) || rune == 0x0670 || rune == 0x0640) continue;
    out.writeCharCode(switch (rune) {
      0x0623 || 0x0625 || 0x0622 || 0x0671 => 0x0627, // أ إ آ ٱ → ا
      0x0629 => 0x0647, // ة → ه
      0x0649 || 0x06CC => 0x064A, // ى ی → ي
      0x06A9 => 0x0643, // ک → ك
      >= 0x0660 && <= 0x0669 => 0x30 + rune - 0x0660, // ٠-٩ → 0-9
      >= 0x06F0 && <= 0x06F9 => 0x30 + rune - 0x06F0, // ۰-۹ → 0-9
      _ => rune,
    });
  }
  return out.toString().toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Strips common Arabic plural and definite-article affixes so a query for
/// "اللمبات" reaches "لمبه". Only used for matching, never for display.
String arStem(String word) {
  var w = word;
  if (w.length > 4 && w.startsWith('ال')) w = w.substring(2);
  for (final suffix in const ['ات', 'ين', 'ون']) {
    if (w.length > 4 && w.endsWith(suffix)) return w.substring(0, w.length - suffix.length);
  }
  if (w.length > 3 && w.endsWith('ه')) return w.substring(0, w.length - 1);
  return w;
}

/// Anything that isn't a Latin letter, digit, Arabic letter or one of `. / -`
/// separates words (as in the database's `search_terms()`).
final _separators = RegExp(
  '[^0-9a-z${String.fromCharCode(0x0621)}-${String.fromCharCode(0x064A)}./-]+',
);
final _edgePunctuation = RegExp(r'^[./-]+|[./-]+$');

/// Normalised, stemmed search terms in [input], each once, in order. Keeps OEM numbers
/// ("04465-0k290"), oil grades ("5w-30") and tyre sizes ("265/65r17") whole.
List<String> searchTerms(String input) => [
  ...{
    for (final raw in arNormalize(input).replaceAll(_separators, ' ').split(' '))
      if (raw.replaceAll(_edgePunctuation, '') case final w when w.isNotEmpty) arStem(w),
  },
];

/// Any Arabic letter (U+0600–U+06FF).
final arabicLetter = RegExp('[${String.fromCharCode(0x0600)}-${String.fromCharCode(0x06FF)}]');

/// A Latin or Arabic letter, for "letters and digits" password rules.
final anyLetter = RegExp('[A-Za-z${String.fromCharCode(0x0600)}-${String.fromCharCode(0x06FF)}]');
