import 'noctra_localization.dart';

/// Pure, localized time-of-day greeting. Kept in core so presentation code
/// can render it without reaching into the data/repository layer.
String timeOfDayGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return NoctraLocalization.tr('good_morning');
  if (hour < 17) return NoctraLocalization.tr('good_afternoon');
  return NoctraLocalization.tr('good_evening');
}
