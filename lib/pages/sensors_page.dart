import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../esp_service.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

enum _State { ok, warming, failing }

class SensorsPage extends StatelessWidget {
  const SensorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: esp,
        builder: (context, _) {
          final d = esp.data;
          if (d == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final warming = d.level == Level.warmup && d.mqOk;
          final items = <_SensorInfo>[
            _SensorInfo(
              icon: Icons.cloud_outlined,
              name: 'MQ-137 Ammonia',
              detail: 'Analog GPIO 34 · Digital GPIO 27',
              value: d.mqOk ? 'Raw ${d.raw}' : 'No valid signal',
              state: !d.mqOk
                  ? _State.failing
                  : (warming ? _State.warming : _State.ok),
              hint: 'Check the AO wire (through a voltage divider), GND and 5 V.',
            ),
            _SensorInfo(
              icon: Icons.thermostat_rounded,
              name: 'DHT22 Temp / Humidity',
              detail: 'Data GPIO 4 · enclosure air',
              value: d.dhtOk && d.temp != null
                  ? '${d.temp!.toStringAsFixed(1)}°C · ${d.hum!.toStringAsFixed(0)}%'
                  : 'No data',
              state: d.dhtOk ? _State.ok : _State.failing,
              hint: 'Check the data wire on GPIO 4, 3.3 V and a 10k pull-up.',
            ),
            _SensorInfo(
              icon: Icons.schedule_rounded,
              name: 'DS3231 Clock (RTC)',
              detail: 'I²C SDA 21 · SCL 22',
              value: d.rtcOk && d.deviceTime != null
                  ? DateFormat('MMM d · HH:mm:ss').format(d.deviceTime!)
                  : 'Not responding',
              state: d.rtcOk ? _State.ok : _State.failing,
              hint: 'Check SDA/SCL wires and the coin cell battery.',
            ),
            _SensorInfo(
              icon: Icons.tv_rounded,
              name: '16x2 LCD Display',
              detail: 'I²C SDA 21 · SCL 22',
              value: d.lcdOk ? 'Detected' : 'Not detected',
              state: d.lcdOk ? _State.ok : _State.failing,
              hint: 'Check SDA/SCL wires and the I²C address (0x27 or 0x3F).',
            ),
          ];
          final good = items.where((e) => e.state != _State.failing).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              const Text('Sensors',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                good == items.length
                    ? 'All ${items.length} working well'
                    : '$good of ${items.length} working well',
                style: TextStyle(
                  color: good == items.length ? kGood : kBad,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              if (esp.sensorErrors.isNotEmpty)
                AlertBanner(
                  icon: Icons.sensors_off_rounded,
                  title: 'Sensor error',
                  message: 'Please check: ${esp.sensorErrors.join(', ')}',
                  color: kBad,
                ),
              for (final s in items) ...[
                _SensorTile(info: s),
                const SizedBox(height: 12),
              ],
              const SectionTitle('OUTPUTS'),
              _OutputTile(
                icon: Icons.mode_fan_off_rounded,
                activeIcon: Icons.air_rounded,
                name: 'Cooling fan',
                detail: 'Relay CH1 · GPIO 25 · ${d.fanMode == FanMode.auto ? 'auto' : 'manual'}',
                on: d.fan,
                onText: 'Running',
                offText: 'Off',
              ),
              const SizedBox(height: 12),
              _OutputTile(
                icon: Icons.volume_off_rounded,
                activeIcon: Icons.volume_up_rounded,
                name: 'Buzzer alarm',
                detail: 'Relay CH2 · GPIO 26',
                on: d.buzzer,
                onText: 'Sounding',
                offText: 'Silent',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SensorInfo {
  final IconData icon;
  final String name;
  final String detail;
  final String value;
  final _State state;
  final String hint;
  const _SensorInfo({
    required this.icon,
    required this.name,
    required this.detail,
    required this.value,
    required this.state,
    required this.hint,
  });
}

class _SensorTile extends StatelessWidget {
  final _SensorInfo info;
  const _SensorTile({required this.info});

  @override
  Widget build(BuildContext context) {
    final failing = info.state == _State.failing;
    final color = switch (info.state) {
      _State.ok => kGood,
      _State.warming => kWarn,
      _State.failing => kBad,
    };
    final text = switch (info.state) {
      _State.ok => 'Working well',
      _State.warming => 'Warming up',
      _State.failing => 'Failing',
    };
    return AppCard(
      borderColor: failing ? alpha(kBad, 0.5) : null,
      color: failing ? Color.lerp(kSurface, kBad, 0.07) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: alpha(color, 0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(info.icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(info.detail,
                        style: const TextStyle(color: kMuted, fontSize: 12.5)),
                  ],
                ),
              ),
              StatusPill(text: text, color: color),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: alpha(Colors.black, 0.22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(info.value,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          if (failing) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.build_circle_outlined, size: 16, color: kBad),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(info.hint,
                      style: const TextStyle(fontSize: 12.5, height: 1.4)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OutputTile extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String name;
  final String detail;
  final bool on;
  final String onText;
  final String offText;
  const _OutputTile({
    required this.icon,
    required this.activeIcon,
    required this.name,
    required this.detail,
    required this.on,
    required this.onText,
    required this.offText,
  });

  @override
  Widget build(BuildContext context) {
    final color = on ? kAccent : kMuted;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: alpha(color, 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(on ? activeIcon : icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Text(detail,
                    style: const TextStyle(color: kMuted, fontSize: 12.5)),
              ],
            ),
          ),
          StatusPill(text: on ? onText : offText, color: color),
        ],
      ),
    );
  }
}
