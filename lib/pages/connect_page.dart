import 'package:flutter/material.dart';

import '../brand.dart';
import '../esp_service.dart';
import '../theme.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  late final TextEditingController _host =
      TextEditingController(text: esp.host);

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: WaveBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: esp,
            builder: (context, _) {
              final failed = esp.error != null;
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ---- brand ------------------------------------------
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: alpha(kAccent, 0.35),
                                blurRadius: 44,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const AppLogo(size: 104),
                        ),
                        const SizedBox(height: 22),
                        Text.rich(
                          TextSpan(
                            text: 'Ammonia',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w300,
                              letterSpacing: -0.5,
                            ),
                            children: const [
                              TextSpan(
                                text: 'Sense',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: kAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          kTagline,
                          style: TextStyle(color: kMuted, fontSize: 14),
                        ),
                        const SizedBox(height: 26),

                        // ---- Aqua says hi -----------------------------------
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            AquaMascot(
                              size: 86,
                              mood: failed ? AquaMood.worried : AquaMood.happy,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: alpha(Colors.white, 0.10),
                                  border: Border.all(
                                      color: alpha(Colors.white, 0.12)),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    topRight: Radius.circular(18),
                                    bottomLeft: Radius.circular(18),
                                    bottomRight: Radius.circular(18),
                                  ),
                                ),
                                child: Text(
                                  failed
                                      ? "Hmm, I can't find your sensor box. "
                                          'Check the WiFi and try again.'
                                      : 'Hi, I am Aqua! Join the AmmoniaMonitor '
                                          'WiFi and I will connect you to your '
                                          'sensor box.',
                                  style: const TextStyle(
                                      height: 1.4, fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // ---- connect card -----------------------------------
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: alpha(kSurface, 0.92),
                            borderRadius: BorderRadius.circular(26),
                            border:
                                Border.all(color: alpha(Colors.white, 0.08)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _Step(
                                n: '1',
                                text: 'Open WiFi settings and join',
                                bold: 'AmmoniaMonitor  ·  password 12345678',
                              ),
                              const SizedBox(height: 14),
                              const _Step(
                                n: '2',
                                text: 'Come back here and tap Connect',
                              ),
                              const SizedBox(height: 18),
                              TextField(
                                controller: _host,
                                keyboardType: TextInputType.url,
                                decoration: const InputDecoration(
                                  labelText: 'Sensor box address',
                                  prefixIcon: Icon(Icons.router_rounded),
                                ),
                              ),
                              if (failed) ...[
                                const SizedBox(height: 12),
                                Text(
                                  esp.error!,
                                  style: const TextStyle(
                                      color: kBad, fontSize: 12.5, height: 1.4),
                                ),
                              ],
                              const SizedBox(height: 18),
                              Material(
                                color: Colors.transparent,
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: esp.connecting
                                          ? [
                                              alpha(kAccent, 0.5),
                                              alpha(const Color(0xFF3A86FF), 0.5)
                                            ]
                                          : const [
                                              kAccent,
                                              Color(0xFF3A86FF)
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: esp.connecting
                                        ? null
                                        : () => esp.connect(_host.text),
                                    child: SizedBox(
                                      height: 54,
                                      width: double.infinity,
                                      child: Center(
                                        child: esp.connecting
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: Color(0xFF06101F),
                                                ),
                                              )
                                            : const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.wifi_rounded,
                                                      color: Color(0xFF06101F)),
                                                  SizedBox(width: 10),
                                                  Text(
                                                    'Connect to sensor box',
                                                    style: TextStyle(
                                                      color: Color(0xFF06101F),
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: esp.connecting ? null : esp.startDemo,
                          child: const Text('Explore with demo data'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String n;
  final String text;
  final String? bold;
  const _Step({required this.n, required this.text, this.bold});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: alpha(kAccent, 0.16),
            shape: BoxShape.circle,
          ),
          child: Text(n,
              style: const TextStyle(
                  color: kAccent, fontWeight: FontWeight.w800, fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text.rich(
              TextSpan(
                text: text,
                children: [
                  if (bold != null)
                    TextSpan(
                      text: '\n$bold',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: kAccent),
                    ),
                ],
              ),
              style: const TextStyle(height: 1.4, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}
