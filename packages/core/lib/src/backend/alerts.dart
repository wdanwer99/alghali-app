import 'package:flutter/foundation.dart' show immutable;

import '../models/catalogue.dart';
import '../models/commerce.dart';

typedef AlertText = ({String title, String body});

/// The wording of every alert code in Arabic and English (`notification_templates`),
/// editable by admins. The inbox and the push dispatcher fill in the same templates
/// with the same rules ([renderAlert], twin of `_shared/notify/render.ts`).
@immutable
class AlertTemplates {
  const AlertTemplates(this._byCode);

  factory AlertTemplates.fromRows(List<Json> rows) {
    final out = <String, Map<String, AlertText>>{};
    for (final r in rows) {
      (out[r['code'] as String] ??= {})[r['locale'] as String] = (
        title: r['title'] as String,
        body: r['body'] as String,
      );
    }
    return AlertTemplates(out);
  }

  static const empty = AlertTemplates({});

  final Map<String, Map<String, AlertText>> _byCode;

  bool get isEmpty => _byCode.isEmpty;

  /// [item] worded in [locale] (Arabic when that language is missing); null for a code
  /// with no template.
  AlertText? render(InboxItem item, String locale) {
    final t = _byCode[item.code]?[locale] ?? _byCode[item.code]?['ar'];
    if (t == null) return null;
    return (
      title: renderAlert(t.title, item.payload, locale),
      body: renderAlert(t.body, item.payload, locale),
    );
  }
}

const _arDays = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
const _enDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const _enMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
];
const _arMonths = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', //
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

String _grouped(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// "12,000 ج.س" / "SDG 12,000".
String alertMoney(int sdg, String locale) =>
    locale == 'ar' ? '${_grouped(sdg)} ج.س' : 'SDG ${_grouped(sdg)}';

/// "الخميس 16 أكتوبر 4:00 م" / "Thu 16 Oct 4:00 PM", Khartoum time (UTC+2).
String alertWhen(DateTime t, String locale) {
  final k = t.toUtc().add(const Duration(hours: 2));
  final h = k.hour;
  final clock = '${h % 12 == 0 ? 12 : h % 12}:${k.minute.toString().padLeft(2, '0')}';
  final day = k.weekday % 7; // DateTime: Monday = 1 … Sunday = 7
  return locale == 'ar'
      ? '${_arDays[day]} ${k.day} ${_arMonths[k.month - 1]} $clock ${h < 12 ? 'ص' : 'م'}'
      : '${_enDays[day]} ${k.day} ${_enMonths[k.month - 1]} $clock ${h < 12 ? 'AM' : 'PM'}';
}

String _value(String key, Object? v, String locale) {
  if (v == null) return '';
  if (key.endsWith('_at') || key == 'pay_by') {
    final t = v is String ? DateTime.tryParse(v) : null;
    return t == null ? '$v' : alertWhen(t, locale);
  }
  if (key.endsWith('_sdg') && v is num) return alertMoney(v.round(), locale);
  if (v is Map || v is List) return '';
  return '$v';
}

/// Fills `{name}` placeholders from [payload]: `*_at` keys become a Khartoum date and
/// time, `*_sdg` keys money; unknown ones are dropped.
String renderAlert(String template, Json payload, String locale) => template
    .replaceAllMapped(RegExp(r'\{([a-z_]+)\}'), (m) => _value(m[1]!, payload[m[1]!], locale))
    .replaceAllMapped(RegExp(r'\s+([.،,:])'), (m) => m[1]!)
    .replaceAll(RegExp(r'\s{2,}'), ' ')
    .trim();

/// The inbox icon for an alert code.
NotificationKind alertKind(String code) => switch (code) {
  _ when code.startsWith('PAYMENT_') || code.startsWith('REFUND_') => NotificationKind.payment,
  _ when code.startsWith('ORDER_') || code.startsWith('RETURN_') => NotificationKind.order,
  _ when code.startsWith('BOOKING_') || code.startsWith('TECH_') || code == 'PART_DOES_NOT_FIT' =>
    NotificationKind.booking,
  'NEW_OFFER' || 'NEW_MESSAGE' => NotificationKind.offer,
  _ => NotificationKind.system,
};
