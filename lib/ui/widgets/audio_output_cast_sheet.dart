import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';
import '../../services/audio/audio_router_service.dart';
import '../../shared/widgets/glass_card.dart';


class AudioOutputCastSheet extends ConsumerStatefulWidget {
  final bool isDark;

  const AudioOutputCastSheet({super.key, required this.isDark});

  @override
  ConsumerState<AudioOutputCastSheet> createState() => _AudioOutputCastSheetState();
}

class _AudioOutputCastSheetState extends ConsumerState<AudioOutputCastSheet> {
  bool _isMultiCastEnabled = false;
  final Set<int> _selectedMultiIds = {};

  @override
  Widget build(BuildContext context) {
    final devicesStream = ref.watch(connectedAudioDevicesProvider);
    final initialDevices = ref.watch(initialAudioDevicesProvider);
    final devices = devicesStream.asData?.value ?? initialDevices.asData?.value;
    final effectiveDevices = devices ?? [
      const AudioDeviceEndpoint(
        id: 1,
        name: 'Built-in Phone Speaker',
        type: 'Phone Speaker',
        typeCode: 2,
        isSink: true,
        isActive: true,
      ),
    ];
    final router = ref.watch(audioRouterServiceProvider);
    final isDark = widget.isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFFAFAFA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AUDIO OUTPUT ROUTER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Device Casting & Multi-Output',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.black12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${effectiveDevices.length} Connected',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Multi-Cast Dual Audio Toggle Card
            GlassCard(
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.hub_outlined, size: 22, color: isDark ? Colors.white : Colors.black),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Multi-Cast Dual Audio',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Simultaneous output to Bluetooth + Speaker / AUX',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _isMultiCastEnabled,
                    activeTrackColor: isDark ? Colors.white : Colors.black,
                    onChanged: (val) {
                      setState(() => _isMultiCastEnabled = val);
                      router.setMultiOutputMode(val, _selectedMultiIds.toList());
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Native Android System Media Switcher / Dual Audio Panel
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: Icon(Icons.tune_rounded, size: 16, color: isDark ? Colors.white70 : Colors.black87),
                label: Text(
                  'Open System Output Panel / Dual Audio',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                onPressed: () => router.openSystemMediaSwitcher(),
              ),
            ),
            const SizedBox(height: 16),

            // Connected Devices List
            Text(
              'SELECT ACTIVE OUTPUT',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
            const SizedBox(height: 8),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: effectiveDevices.length,
              itemBuilder: (context, index) {
                final dev = effectiveDevices[index];
                final isSelected = dev.isActive || (_isMultiCastEnabled && _selectedMultiIds.contains(dev.id));
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    radius: 14,
                    isHighlighted: isSelected,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: InkWell(
                      onTap: () {
                        if (_isMultiCastEnabled) {
                          setState(() {
                            if (_selectedMultiIds.contains(dev.id)) {
                              _selectedMultiIds.remove(dev.id);
                            } else {
                              _selectedMultiIds.add(dev.id);
                            }
                          });
                          router.setMultiOutputMode(true, _selectedMultiIds.toList());
                        } else {
                          router.setOutputDevice(dev.id);
                        }
                      },
                      child: Row(
                        children: [
                          Icon(_getDeviceIcon(dev.type), size: 22, color: isDark ? Colors.white : Colors.black),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dev.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dev.type,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontFamily: 'monospace',
                                    color: isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white : Colors.black,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              ),
                            )
                          else
                            Icon(
                              _isMultiCastEnabled ? Icons.check_box_outline_blank : Icons.radio_button_off,
                              size: 18,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  IconData _getDeviceIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('bluetooth') || lower.contains('wireless') || lower.contains('ble')) {
      return Icons.bluetooth_audio_rounded;
    }
    if (lower.contains('aux') || lower.contains('headphone') || lower.contains('headset')) {
      return Icons.headphones_rounded;
    }
    if (lower.contains('usb') || lower.contains('dac')) {
      return Icons.usb_rounded;
    }
    return Icons.volume_up_rounded;
  }
}
