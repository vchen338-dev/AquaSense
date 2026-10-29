import 'package:flutter/material.dart';

import '../assistant.dart';
import '../brand.dart';
import '../esp_service.dart';
import '../fish.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([esp, tank]),
        builder: (context, _) {
          final d = esp.data;
          if (d == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final errors = d.failingSensors;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              // ---- header --------------------------------------------------
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_greeting(),
                            style:
                                const TextStyle(color: kMuted, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(tank.tankName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 26, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  StatusPill(
                    text: esp.demo ? 'Demo' : 'Live',
                    color: esp.demo ? kWarn : kGood,
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => showAssistant(context),
                    child: AquaMascot(size: 48, mood: aquaMoodFor(d.level)),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ---- alerts --------------------------------------------------
              if (errors.isNotEmpty)
                AlertBanner(
                  icon: Icons.sensors_off_rounded,
                  title: 'Sensor error',
                  message: 'Please check: ${errors.join(', ')}',
                  color: kBad,
                ),
              if (d.level == Level.high)
                const AlertBanner(
                  icon: Icons.warning_amber_rounded,
                  title: 'Ammonia is HIGH',
                  message: 'Do a water change now and stop feeding.',
                  color: kBad,
                )
              else if (d.level == Level.mid)
                const AlertBanner(
                  icon: Icons.info_outline_rounded,
                  title: 'Ammonia is rising',
                  message: 'Keep an eye on it and consider a water change.',
                  color: kWarn,
                ),

              // ---- aquarium -----------------------------------------------
              _AquariumCard(d: d),
              const SizedBox(height: 16),

              // ---- ammonia gauge ------------------------------------------
              _GaugeCard(d: d),
              const SizedBox(height: 0),

              // ---- enclosure -----------------------------------------------
              const SectionTitle('INSIDE THE SENSOR BOX'),
              Row(
                children: [
                  Expanded(
                    child: _MiniTile(
                      icon: Icons.thermostat_rounded,
                      label: 'Box temperature',
                      value: d.temp == null
                          ? '--'
                          : '${d.temp!.toStringAsFixed(1)}°C',
                      footer: d.dhtOk
                          ? StatusPill(
                              text: d.fan ? 'Fan ON' : 'Fan OFF',
                              color: d.fan ? kAccent : kMuted)
                          : const StatusPill(text: 'DHT22 error', color: kBad),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _MiniTile(
                      icon: Icons.water_rounded,
                      label: 'Box humidity',
                      value: d.hum == null
                          ? '--'
                          : '${d.hum!.toStringAsFixed(0)}%',
                      footer: StatusPill(
                        text: d.dhtOk ? 'DHT22 OK' : 'No data',
                        color: d.dhtOk ? kGood : kBad,
                      ),
                    ),
                  ),
                ],
              ),

              // ---- assistant ----------------------------------------------
              const SectionTitle('ASSISTANT'),
              _AssistantCard(),
            ],
          );
        },
      ),
    );
  }
}

class _AquariumCard extends StatelessWidget {
  final LiveData d;
  const _AquariumCard({required this.d});

  @override
  Widget build(BuildContext context) {
    final idxText = d.level == Level.warmup || d.level == Level.fault
        ? '--'
        : '${d.index}';
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: SizedBox(
        height: 360,
        child: Stack(
          children: [
            Positioned.fill(child: AquariumView(level: d.level)),
            // top row
            Positioned(
              left: 14,
              right: 14,
              top: 14,
              child: Row(
                children: [
                  Glass(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tank.type == TankType.pond ? Icons.water_rounded : Icons.set_meal_rounded,
                            size: 16, color: tank.color),
                        const SizedBox(width: 8),
                        Text(
                          tank.count > 1
                              ? '${tank.fishName} · ×${tank.count}'
                              : tank.fishName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _editFish(context),
                    child: const Glass(
                      padding: EdgeInsets.all(9),
                      child: Icon(Icons.tune_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            // live readings
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Glass(
                child: Row(
                  children: [
                    _Reading(
                      label: 'NH₃ INDEX',
                      value: idxText,
                      color: levelColor(d.level),
                    ),
                    _divider(),
                    _Reading(
                      label: 'RAW',
                      value: d.mqOk ? '${d.raw}' : '--',
                    ),
                    _divider(),
                    _Reading(
                      label: 'WATER STATUS',
                      value: levelLabel(d.level),
                      color: levelColor(d.level),
                      small: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _divider() => Container(
        width: 1,
        height: 30,
        color: alpha(Colors.white, 0.14),
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );

  void _editFish(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 22, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Customize your tank',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            SizedBox(height: 18),
            FishCustomizer(),
          ],
        ),
      ),
    );
  }
}

class _Reading extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool small;
  const _Reading({
    required this.label,
    required this.value,
    this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: small ? 14 : 20,
              fontWeight: FontWeight.w800,
              color: color ?? kText,
            ),
          ),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: kMuted)),
        ],
      ),
    );
  }
}

class _GaugeCard extends StatelessWidget {
  final LiveData d;
  const _GaugeCard({required this.d});

  @override
  Widget build(BuildContext context) {
    final known = d.level != Level.warmup && d.level != Level.fault;
    return AppCard(
      child: Row(
        children: [
          ArcGauge(
            value: known ? d.index / 100 : 0,
            size: 148,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  known ? '${d.index}' : '--',
                  style: const TextStyle(
                      fontSize: 38, fontWeight: FontWeight.w800, height: 1),
                ),
                const SizedBox(height: 4),
                const Text('NH₃ index',
                    style: TextStyle(color: kMuted, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ammonia',
                    style: TextStyle(color: kMuted, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  levelLabel(d.level),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: levelColor(d.level),
                  ),
                ),
                const SizedBox(height: 12),
                _kv('Raw reading', '${d.raw}'),
                _kv('Rising at', '${d.mid}'),
                _kv('Danger at', '${d.high}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Text(k, style: const TextStyle(color: kMuted, fontSize: 12.5)),
            const Spacer(),
            Text(v,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      );
}

class _MiniTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget footer;
  const _MiniTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: kAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kMuted, fontSize: 12.5)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value,
              style:
                  const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          footer,
        ],
      ),
    );
  }
}

class _AssistantCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const quick = [
      'Is my water safe right now?',
      'How do I lower ammonia fast?',
      'Care tips for my fish',
    ];
    final level = esp.data?.level ?? Level.low;
    final line = switch (level) {
      Level.mid => 'Hi, I am Aqua. The ammonia is rising, want some tips?',
      Level.high => 'Hi, I am Aqua. Ammonia is high! Ask me what to do.',
      Level.fault => 'Hi, I am Aqua. One of my sensors needs a check.',
      _ => 'Hi, I am Aqua! Ask me anything about your tank.',
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [alpha(kAccent, 0.20), alpha(const Color(0xFF3A86FF), 0.16)],
        ),
        border: Border.all(color: alpha(kAccent, 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AquaMascot(size: 74, mood: aquaMoodFor(level)),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: alpha(Colors.black, 0.25),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                  ),
                  child: Text(line,
                      style: const TextStyle(height: 1.4, fontSize: 14)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in quick)
                ActionChip(
                  label: Text(q, style: const TextStyle(fontSize: 12.5)),
                  backgroundColor: alpha(Colors.black, 0.25),
                  side: BorderSide.none,
                  onPressed: () => showAssistant(context, ask: q),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => showAssistant(context),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('Chat with Aqua'),
            ),
          ),
        ],
      ),
    );
  }
}
