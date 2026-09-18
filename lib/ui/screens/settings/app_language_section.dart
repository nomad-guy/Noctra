import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/noctra_localization.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../core/theme/noir_theme.dart';

class AppLanguageSection extends ConsumerWidget {
  final bool isDark;

  const AppLanguageSection({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.noctraTokens;
    ref.watch(appLanguageProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          NoctraLocalization.tr('language').toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: t.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          radius: 16,
          padding: const EdgeInsets.all(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Language / भाषा',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: t.primaryText,
                ),
              ),
              DropdownButton<String>(
                value: ref.watch(appLanguageProvider),
                dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                underline: const SizedBox.shrink(),
                style: TextStyle(
                  fontSize: 13,
                  color: t.primaryText,
                ),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'hi', child: Text('हिंदी (Hindi)')),
                  DropdownMenuItem(value: 'pa', child: Text('ਪੰਜਾਬੀ (Punjabi)')),
                  DropdownMenuItem(value: 'ur', child: Text('اردو (Urdu)')),
                  DropdownMenuItem(value: 'kn', child: Text('ಕನ್ನಡ (Kannada)')),
                  DropdownMenuItem(value: 'ta', child: Text('தமிழ் (Tamil)')),
                  DropdownMenuItem(value: 'mr', child: Text('मराठी (Marathi)')),
                  DropdownMenuItem(value: 'or', child: Text('ଓଡ଼ିଆ (Odia)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    updateAppLanguage(ref, val);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
