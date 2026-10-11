import 'dart:math';

/// Luhn check digit for [digits] (D-016): catches any single mistyped digit
/// and most swaps when the buyer types the reference into Bankak.
int luhnCheckDigit(String digits) {
  var sum = 0;
  for (var i = 0; i < digits.length; i++) {
    var d = digits.codeUnitAt(digits.length - 1 - i) - 0x30;
    if (i.isEven) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
  }
  return (10 - sum % 10) % 10;
}

bool isValidRef(String ref) =>
    RegExp(r'^\d{8}$').hasMatch(ref) &&
    luhnCheckDigit(ref.substring(0, 7)) == ref.codeUnitAt(7) - 0x30;

/// A new 8-digit order reference: 7 random digits (no leading zero) + check digit.
String newOrderRef([Random? random]) {
  final r = random ?? Random.secure();
  final body = '${1 + r.nextInt(9)}${List.generate(6, (_) => r.nextInt(10)).join()}';
  return '$body${luhnCheckDigit(body)}';
}

/// A 4-digit job code the buyer gives the technician when the job is done.
String newJobCode([Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(4, (_) => r.nextInt(10)).join();
}
