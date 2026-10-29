import 'package:flutter/material.dart';

import 'brand.dart';
import 'esp_service.dart';
import 'fish.dart';
import 'models.dart';
import 'theme.dart';

class _Q {
  final String id;
  final String text;
  const _Q(this.id, this.text);
}

const List<_Q> kQuestions = [
  _Q('safe', 'Is my water safe right now?'),
  _Q('causes', 'What causes high ammonia?'),
  _Q('lower', 'How do I lower ammonia fast?'),
  _Q('change', 'How often should I change water?'),
  _Q('care', 'Care tips for my fish'),
  _Q('temp', 'What temperature is best for my fish?'),
  _Q('fan', 'Why is the fan on?'),
  _Q('levels', 'How do I change the alarm levels?'),
  _Q('beep', 'What does the beeping mean?'),
  _Q('sensor', 'A sensor shows an error. What now?'),
];

String _idFor(String input) {
  final s = input.toLowerCase();
  bool has(List<String> k) => k.any(s.contains);
  for (final q in kQuestions) {
    if (q.text.toLowerCase() == s.trim()) return q.id;
  }
  final t = s.trim();
  if (t == 'hi' || t == 'hey' || t.startsWith('hello') || t.startsWith('hi ')) {
    return 'hello';
  }
  if (has(['safe', 'ammonia level', 'status', 'how is'])) return 'safe';
  if (has(['cause', 'why is ammonia', 'why high', 'source'])) return 'causes';
  if (has(['lower', 'reduce', 'fix', 'remove', 'high ammonia', 'fast'])) {
    return 'lower';
  }
  if (has(['water change', 'how often', 'change water', 'clean'])) return 'change';
  if (has(['threshold', 'alarm level', 'sensitiv', 'calibrat', 'change the alarm'])) {
    return 'levels';
  }
  if (has(['fan', 'cooling'])) return 'fan';
  if (has(['beep', 'buzzer', 'alarm', 'sound'])) return 'beep';
  if (has(['care', 'tips', 'feed', 'tilapia', 'shrimp', 'crayfish', 'betta', 'about my fish'])) {
    return 'care';
  }
  if (has(['temperature', 'temp', 'warm', 'cold', 'heat'])) return 'temp';
  if (has(['sensor', 'error', 'fail', 'broken'])) return 'sensor';
  return 'unknown';
}

/// Pre-made answers. Some use the live sensor data.
String answerFor(String input) {
  final id = _idFor(input);
  final d = esp.data;
  final fish = tank.fish;
  final name = tank.fishName;

  switch (id) {
    case 'hello':
      return "Hi! I'm Aqua. Tap one of the questions below and I'll help with "
          'your tank.';
    case 'safe':
      if (d == null) return "I can't see the sensor right now.";
      final base = switch (d.level) {
        Level.low => 'Looks good. Ammonia is in the safe range (index ${d.index}/100). '
            '$name should be comfortable. Remember this sensor reads ammonia '
            'gas near the tank, so confirm sometimes with a liquid water test '
            'kit. The target is 0 ppm.',
        Level.mid => 'Ammonia is rising (index ${d.index}/100). Do a 25-30% water '
            'change with dechlorinated water, skip the next feeding, and '
            'remove any uneaten food.',
        Level.high => 'Danger. Ammonia is HIGH (index ${d.index}/100). Do a 40-50% '
            'water change now, stop feeding, add extra aeration, and check '
            'for a dead fish or rotting food.',
        Level.warmup => 'The ammonia sensor is still warming up. Give it a minute or '
            'two for a stable reading.',
        Level.fault => "I can't judge the water because the ammonia sensor has an "
            'error. Open the Sensors tab and check the MQ-137 wiring.',
      };
      if (fish == FishType.shrimp) {
        return '$base\n\nShrimp are very sensitive to ammonia, so act early.';
      }
      if (fish == FishType.crayfish) {
        return '$base\n\nCrayfish handle a bit more than shrimp but still '
            'suffer in high ammonia, so do not wait.';
      }
      if (fish == FishType.neon) {
        return '$base\n\nNeon tetras are sensitive to ammonia, so act early.';
      }
      return base;
    case 'causes':
      return 'Common causes of ammonia:\n'
          '- Overfeeding and uneaten food rotting\n'
          '- Too many fish for the tank size\n'
          '- A new tank that is not cycled yet\n'
          '- A dirty or over-cleaned filter (bacteria die)\n'
          '- A dead fish or plant decaying\n'
          '- Tap water containing chloramine';
    case 'lower':
      final pondExtra = tank.type == TankType.pond
          ? '\n7. In a pond also run a pump or aerator, remove leaves and '
              'sludge from the bottom, and reduce the number of fish if it is '
              'crowded.'
          : '';
      return 'To bring ammonia down quickly:\n'
          '1. Change 30-50% of the water with dechlorinated water at the same '
          'temperature.\n'
          '2. Stop feeding for a day or two.\n'
          '3. Remove dead plants and leftover food.\n'
          '4. Add aeration, since more oxygen helps the good bacteria.\n'
          '5. Use an ammonia-binding conditioner as a short-term help.\n'
          "6. Don't wash the filter media in tap water."
          '$pondExtra';
    case 'change':
      if (tank.type == TankType.pond) {
        return 'In a pond, change about 10-20% of the water every week or two '
            'depending on how many fish you keep. Keep a pump or aerator '
            'running, feed only what the fish finish in a few minutes, and '
            'avoid big sudden changes that can shock the fish.';
      }
      return 'A good rule is 20-30% every week. Small tanks and heavily stocked '
          'tanks do better with a smaller change twice a week. Always treat '
          'new water with a dechlorinator and match the temperature.';
    case 'temp':
      final t = d?.temp;
      final now = t == null
          ? ''
          : '\n\nYour enclosure sensor reads ${t.toStringAsFixed(1)} °C right '
              'now.';
      return 'The ideal water temperature for ${fish.label.toLowerCase()} is '
          '${fish.tempRange}. Note that the '
          'DHT22 measures the air temperature inside the enclosure, not the '
          'water, so use a water thermometer for the water.$now';
    case 'care':
      return switch (fish) {
        FishType.betta => 'Betta care: keep the water at ${fish.tempRange}, '
            'use a gentle filter, feed small amounts once or twice a day, and '
            'keep males apart. They need clean water, so watch ammonia.',
        FishType.goldfish => 'Goldfish care: they produce a lot of waste, so '
            'use strong filtration and give them plenty of space. Feed small '
            'portions and change water weekly.',
        FishType.guppy => 'Guppy care: keep them in a group at '
            '${fish.tempRange}, feed small amounts, and watch the numbers '
            'because they breed quickly.',
        FishType.neon => 'Neon tetra care: keep at least 6 together at '
            '${fish.tempRange} in soft, stable water. They are sensitive to '
            'ammonia and sudden changes.',
        FishType.tilapia => 'Tilapia care: they are hardy and grow fast at '
            '${fish.tempRange}. They eat and produce a lot of waste, so give '
            'them good aeration, avoid overfeeding, and change water often. '
            'Do not overcrowd.',
        FishType.shrimp => 'Shrimp care: keep the water stable at '
            '${fish.tempRange}. They are very sensitive to ammonia and to '
            'copper (found in some medicines and fertilizers). Add hiding '
            'places and acclimate new shrimp slowly.',
        FishType.crayfish => 'Crayfish care: keep them at ${fish.tempRange} '
            'with lots of hiding places such as pipes and rocks. They are '
            'hungry and messy, so remove leftovers fast. Give them calcium '
            'for shell growth, keep tight lid because they climb out, and '
            'do not mix with small fish or shrimp (they will hunt them).',
      };
    case 'fan':
      if (d == null) return 'The fan is controlled by the enclosure temperature.';
      final temp = d.temp == null
          ? 'unknown'
          : '${d.temp!.toStringAsFixed(1)} °C';
      final mode = switch (d.fanMode) {
        FanMode.auto => 'The fan is in AUTO: it switches on at '
            '${d.fanOnC.toStringAsFixed(1)} °C and off again at '
            '${d.fanOffC.toStringAsFixed(1)} °C to protect the electronics.',
        FanMode.on => 'The fan is forced ON by you (manual mode).',
        FanMode.off => 'The fan is forced OFF by you (manual mode).',
      };
      return '$mode Right now the box is $temp and the fan is '
          '${d.fan ? 'ON' : 'OFF'}.\n\nYou can change this in the Control tab.';
    case 'levels':
      return 'Open the Control tab. Drag the two handles on the Ammonia alarm '
          'bar: the left one sets where the slow beep starts (mid), the right '
          'one sets the rapid beep (high). Then press Save to device.\n\n'
          'Right now: mid ${d?.mid ?? '-'}, high ${d?.high ?? '-'}, and the '
          'live reading is ${d?.raw ?? '-'}.\n\nTip: note the reading in '
          'clean air and the reading near a little ammonia, then set the '
          'levels between those two numbers.';
    case 'beep':
      return 'Buzzer patterns:\n'
          '- Slow beep: ammonia is rising (mid)\n'
          '- Rapid beep: ammonia is HIGH\n'
          '- Two beeps every 2 seconds: a sensor is failing';
    case 'sensor':
      final bad = esp.sensorErrors;
      final list = bad.isEmpty
          ? 'All sensors look fine at the moment.'
          : 'Failing now: ${bad.join(', ')}.';
      return '$list\n\nTry this:\n'
          '- Check the wires and pins on the failing part (see the Sensors '
          'tab)\n'
          '- Make sure the DHT22 data line is on GPIO 4 with a pull-up\n'
          '- The MQ-137 reading should not sit at 0 or at the maximum\n'
          '- Power the ESP32 off and on again after fixing a wire';
    default:
      return "I only know a few topics so far. Try one of the suggested "
          'questions below.';
  }
}

Future<void> showAssistant(BuildContext context, {String? ask}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: kSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _AssistantSheet(initial: ask),
  );
}

String _intro() {
  final d = esp.data;
  final what = tank.type == TankType.pond ? 'pond' : 'aquarium';
  final status = d == null
      ? ''
      : switch (d.level) {
          Level.low => ' Right now the ammonia looks calm.',
          Level.mid => ' Heads up, the ammonia is rising a little.',
          Level.high => ' Careful, the ammonia is HIGH right now!',
          Level.warmup => ' My sensor is still warming up.',
          Level.fault => ' I think my ammonia sensor has a problem.',
        };
  return 'Hi, I am Aqua! I look after your $what, ${tank.tankName}.$status '
      'What would you like to know?';
}

class _Msg {
  final String text;
  final bool mine;
  _Msg(this.text, this.mine);
}

class _AssistantSheet extends StatefulWidget {
  final String? initial;
  const _AssistantSheet({this.initial});

  @override
  State<_AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends State<_AssistantSheet> {
  late final List<_Msg> _msgs = [_Msg(_intro(), false)];
  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  bool _typing = false;

  AquaMood get _mood => aquaMoodFor(esp.data?.level ?? Level.low);

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ask(widget.initial!));
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ask(String q) async {
    if (q.trim().isEmpty) return;
    setState(() {
      _msgs.add(_Msg(q.trim(), true));
      _typing = true;
    });
    _ctl.clear();
    _toBottom();
    await Future.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;
    setState(() {
      _msgs.add(_Msg(answerFor(q), false));
      _typing = false;
    });
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.84,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: alpha(Colors.white, 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // ---- header with Aqua -------------------------------------------
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  colors: [
                    alpha(kAccent, 0.18),
                    alpha(const Color(0xFF3A86FF), 0.14),
                  ],
                ),
                border: Border.all(color: alpha(kAccent, 0.25)),
              ),
              child: Row(
                children: [
                  AquaMascot(size: 68, mood: _mood),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Aqua',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                  color: kGood, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            const Text('Online · your tank buddy',
                                style:
                                    TextStyle(color: kMuted, fontSize: 12.5)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: _msgs.length + (_typing ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _msgs.length) {
                    return _AquaRow(mood: _mood, child: const _TypingDots());
                  }
                  final m = _msgs[i];
                  if (m.mine) return _UserBubble(text: m.text);
                  return _AquaRow(
                    mood: _mood,
                    child: Text(m.text,
                        style: const TextStyle(height: 1.4, fontSize: 14.5)),
                  );
                },
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: kQuestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ActionChip(
                  label: Text(kQuestions[i].text),
                  backgroundColor: kSurface2,
                  side: BorderSide.none,
                  onPressed: () => _ask(kQuestions[i].text),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _ask,
                      decoration: const InputDecoration(
                        hintText: 'Ask Aqua something...',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: () => _ask(_ctl.text),
                    style: IconButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: const Color(0xFF06101F),
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An Aqua message: small fish avatar + speech bubble.
class _AquaRow extends StatelessWidget {
  final AquaMood mood;
  final Widget child;
  const _AquaRow({required this.mood, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AquaMascot(size: 38, mood: mood, animate: false),
          const SizedBox(width: 6),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72),
              decoration: const BoxDecoration(
                color: kSurface2,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(5),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: const BoxDecoration(
          color: kAccent,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(5),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF06101F),
            height: 1.4,
            fontSize: 14.5,
          ),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: alpha(kMuted, 0.4 + 0.6 * _pulse(i)),
              ),
            ),
        ],
      ),
    );
  }

  double _pulse(int i) {
    final v = (_c.value - i * 0.18) % 1.0;
    return v < 0.4 ? (1 - (v - 0.2).abs() / 0.2).clamp(0.0, 1.0) : 0.0;
  }
}
