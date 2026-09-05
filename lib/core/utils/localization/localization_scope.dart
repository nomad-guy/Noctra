import 'package:flutter/widgets.dart';
import '../noctra_localization.dart';

/// An InheritedWidget that provides reactive localization updates to the
/// widget tree whenever the user changes the application language.
class NoctraLocalizationScope extends InheritedWidget {
  final String languageCode;

  const NoctraLocalizationScope({
    super.key,
    required this.languageCode,
    required super.child,
  });

  static NoctraLocalizationScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NoctraLocalizationScope>();
  }

  @override
  bool updateShouldNotify(NoctraLocalizationScope oldWidget) =>
      languageCode != oldWidget.languageCode;
}

/// Convenience extension on BuildContext to resolve translated strings and
/// automatically register the calling widget to rebuild upon language switches.
extension LocalizationContextX on BuildContext {
  String tr(String key, [Map<String, dynamic>? args]) {
    final scope = dependOnInheritedWidgetOfExactType<NoctraLocalizationScope>();
    return NoctraLocalization.tr(
      key,
      language: scope?.languageCode,
      args: args,
    );
  }
}
