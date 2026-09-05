import 'package:flutter/widgets.dart';
import 'localization/localization_keys.dart';
import 'localization/localization_scope.dart';
import 'noctra_localization.dart';

/// Pure, localized time-of-day greeting. Kept in core so presentation code
/// can render it without reaching into the data/repository layer.
String timeOfDayGreeting([BuildContext? context]) {
  final hour = DateTime.now().hour;
  final key = hour < 12
      ? L10nKeys.goodMorning
      : (hour < 17 ? L10nKeys.goodAfternoon : L10nKeys.goodEvening);
  return context != null ? context.tr(key) : NoctraLocalization.tr(key);
}
