/// Client-side twin of the database's `ar_normalize()` (D-006): unifies alef
/// and taa-marbuta/yaa spellings, strips diacritics and tatweel, lower-cases
/// Latin and collapses whitespace, so "لمبة", "لمبه" and "لمبات" all match.
String arNormalize(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    if ((rune >= 0x064B && rune <= 0x0652) || rune == 0x0670 || rune == 0x0640) continue;
    out.writeCharCode(switch (rune) {
      0x0623 || 0x0625 || 0x0622 || 0x0671 => 0x0627, // أ إ آ ٱ → ا
      0x0629 => 0x0647, // ة → ه
      0x0649 => 0x064A, // ى → ي
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

/// Normalised, stemmed search terms in [input].
List<String> searchTerms(String input) =>
    arNormalize(input).split(' ').where((w) => w.isNotEmpty).map(arStem).toList();

/// Any Arabic letter (U+0600–U+06FF).
final arabicLetter = RegExp('[${String.fromCharCode(0x0600)}-${String.fromCharCode(0x06FF)}]');

/// A Latin or Arabic letter, for "letters and digits" password rules.
final anyLetter = RegExp('[A-Za-z${String.fromCharCode(0x0600)}-${String.fromCharCode(0x06FF)}]');
