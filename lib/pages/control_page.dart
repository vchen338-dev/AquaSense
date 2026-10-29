import 'package:flutter/material.dart';

import '../esp_service.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// Fan control and alarm thresholds. Everything here is stored on the ESP32,
/// so the settings stay even when the phone is gone.
class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  static const _defMid = 1200.0, _defHigh = 2200.0;
  static const _minRaw = 100.0, _maxRaw = 4000.0, _minGap = 100.0;

  RangeValues _range = const RangeValues(_defMid, _defHigh);
  double _fanOn = 32;
  bool _dirty = false;
  bool _fanDrag = false;
  bool _saving = false;

  void _sync(LiveData d) {
    if (!_dirty) {
      _range = RangeValues(
        d.mid.toDouble().clamp(_minRaw, _maxRaw),
        d.high.toDouble().clamp(_minRaw + _minGap, _maxRaw),
      );
    }
    if (!_fanDrag) _fanOn = d.fanOnC.clamp(25.0, 45.0);
  }

  void _toast(String msg, {bool bad = false}) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: bad ? const Color(0xFF3A1820) : kSurface2,
      duration: const Duration(seconds: 3),
      content: Text(msg),
    ));
  }

  Future<void> _setMode(FanMode m) async {
    final ok = await esp.setFanMode(m);
    if (!mounted) return;
    if (!ok) _toast('Could not reach the sensor box.', bad: true);
  }

  Future<void> _saveFanTemp(double v) async {
    final ok = await esp.saveSettings(fanOnC: v);
    if (!mounted) return;
    setState(() => _fanDrag = false);
    _toast(ok
        ? 'Fan will turn on at ${v.toStringAsFixed(1)} °C'
        : 'Could not save. Check the connection.', bad: !ok);
  }

  Future<void> _saveThresholds() async {
    setState(() => _saving = true);
    final ok = await esp.saveSettings(
      mid: _range.start.round(),
      high: _range.end.round(),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _dirty = false;
    });
    _toast(ok ? 'Thresholds saved to the sensor box' : 'Could not save. Check the connection.',
        bad: !ok);
  }

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
          _sync(d);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              const Text('Control',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Settings are saved inside the sensor box.',
                  style: TextStyle(color: kMuted)),
              const SectionTitle('COOLING FAN'),
              _fanCard(d),
              const SectionTitle('AMMONIA ALARM LEVELS'),
              _thresholdCard(d),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------- fan
  Widget _fanCard(LiveData d) {
    final manual = d.fanMode != FanMode.auto;
    final color = d.fan ? kAccent : kMuted;
    final modeText = switch (d.fanMode) {
      FanMode.auto => 'Automatic: follows the box temperature',
      FanMode.on => 'Manual: forced ON',
      FanMode.off => 'Manual: forced OFF',
    };
    final temp = d.temp;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: alpha(color, 0.16),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                    d.fan ? Icons.air_rounded : Icons.mode_fan_off_rounded,
                    color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.fan ? 'Fan is ON' : 'Fan is OFF',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 17)),
                    const SizedBox(height: 2),
                    Text(modeText,
                        style: const TextStyle(color: kMuted, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<FanMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: FanMode.auto,
                    icon: Icon(Icons.auto_mode_rounded),
                    label: Text('Auto')),
                ButtonSegment(
                    value: FanMode.on,
                    icon: Icon(Icons.power_settings_new_rounded),
                    label: Text('On')),
                ButtonSegment(
                    value: FanMode.off,
                    icon: Icon(Icons.block_rounded),
                    label: Text('Off')),
              ],
              selected: {d.fanMode},
              onSelectionChanged: (v) => _setMode(v.first),
            ),
          ),
          const SizedBox(height: 22),
          Opacity(
            opacity: manual ? 0.45 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Turn on at',
                        style: TextStyle(
                            color: kMuted, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('${_fanOn.toStringAsFixed(1)} °C',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                  ],
                ),
                Slider(
                  value: _fanOn,
                  min: 25,
                  max: 45,
                  divisions: 40,
                  label: '${_fanOn.toStringAsFixed(1)} °C',
                  onChangeStart: (_) => _fanDrag = true,
                  onChanged: (v) => setState(() => _fanOn = v),
                  onChangeEnd: _saveFanTemp,
                ),
                Text(
                  'Turns off again at ${(_fanOn - 2).toStringAsFixed(1)} °C. '
                  '${temp == null ? 'Box temperature unavailable.' : 'Box is now ${temp.toStringAsFixed(1)} °C.'}'
                  '${manual ? '\nSet Auto to use this temperature.' : ''}',
                  style: const TextStyle(
                      color: kMuted, fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ thresholds
  Widget _thresholdCard(LiveData d) {
    final mid = _range.start, high = _range.end;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _valueTile('Slow beep from', mid.round(), kWarn),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _valueTile('Rapid beep from', high.round(), kBad),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _zoneBar(mid, high, d.raw),
          const SizedBox(height: 2),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: alpha(kWarn, 0.0),
              inactiveTrackColor: alpha(kWarn, 0.0),
              rangeThumbShape: const RoundRangeSliderThumbShape(
                  enabledThumbRadius: 11),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 11),
              overlayColor: alpha(kAccent, 0.15),
              thumbColor: kAccent,
            ),
            child: RangeSlider(
              values: _range,
              min: _minRaw,
              max: _maxRaw,
              divisions: 78,
              onChanged: (v) {
                if (v.end - v.start < _minGap) return;
                setState(() {
                  _range = v;
                  _dirty = true;
                });
              },
            ),
          ),
          Text(
            'Live reading now: ${d.raw}. Lower numbers make the alarm more '
            'sensitive. Test in clean air first, then near a small known '
            'ammonia source, and set the levels between the two.',
            style:
                const TextStyle(color: kMuted, fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            _range = const RangeValues(_defMid, _defHigh);
                            _dirty = true;
                          }),
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Defaults'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kText,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: alpha(Colors.white, 0.18)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: (_dirty && !_saving) ? _saveThresholds : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_rounded),
                  label: const Text('Save to device'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _valueTile(String label, int v, Color c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: alpha(c, 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: kMuted, fontSize: 12.5)),
          const SizedBox(height: 4),
          Text('$v',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: c)),
        ],
      ),
    );
  }

  /// Coloured bar lined up with the range slider below it (same 11 px inset).
  Widget _zoneBar(double mid, double high, int? raw) {
    const lo = _minRaw, hi = _maxRaw;
    int fx(double v) => v.round().clamp(1, 100000);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11),
      child: LayoutBuilder(builder: (_, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: 28,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                top: 9,
                bottom: 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Row(
                    children: [
                      Expanded(
                          flex: fx(mid - lo),
                          child: Container(color: alpha(kGood, 0.8))),
                      Expanded(
                          flex: fx(high - mid),
                          child: Container(color: alpha(kWarn, 0.9))),
                      Expanded(
                          flex: fx(hi - high),
                          child: Container(color: alpha(kBad, 0.9))),
                    ],
                  ),
                ),
              ),
              if (raw != null)
                Positioned(
                  left: ((raw - lo) / (hi - lo)).clamp(0.0, 1.0) * w - 1.5,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
