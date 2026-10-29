import 'package:flutter/material.dart';

import '../esp_service.dart';
import '../fish.dart';
import '../theme.dart';
import '../widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: esp,
        builder: (context, _) {
          final d = esp.data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              const Text('Settings',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SectionTitle('YOUR TANK'),
              const AppCard(child: FishCustomizer()),

              const SectionTitle('CONNECTION'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: alpha(kGood, 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.wifi_rounded, color: kGood),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(esp.demo ? 'Demo mode' : 'Connected',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16)),
                              Text(
                                  esp.demo
                                      ? 'Simulated data'
                                      : '${esp.host}  ·  up ${_uptime(d?.uptime ?? 0)}',
                                  style: const TextStyle(
                                      color: kMuted, fontSize: 12.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: esp.disconnect,
                        icon: const Icon(Icons.link_off_rounded),
                        label: const Text('Disconnect'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kText,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: alpha(Colors.white, 0.18)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (esp.demo) ...[
                const SectionTitle('DEMO'),
                AppCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Simulate sensor error'),
                    subtitle: const Text('Makes the DHT22 fail'),
                    value: esp.demoFault,
                    activeColor: kAccent,
                    onChanged: esp.setDemoFault,
                  ),
                ),
              ],

              const SectionTitle('DATA'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${esp.readings.length} records saved on this phone. '
                      'The sensor box also keeps its own copy (CSV on its '
                      'flash memory) so nothing is lost when the app is closed.',
                      style: const TextStyle(
                          color: kMuted, fontSize: 13, height: 1.45),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmClear(context),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Clear all records'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kBad,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: alpha(kBad, 0.5)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _uptime(int s) {
    if (s >= 3600) return '${s ~/ 3600}h ${(s % 3600) ~/ 60}m';
    if (s >= 60) return '${s ~/ 60}m';
    return '${s}s';
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Clear all records?'),
        content: const Text(
            'This deletes the history on your phone and on the sensor box.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: kBad))),
        ],
      ),
    );
    if (ok == true) await esp.clearDeviceRecords();
  }
}
