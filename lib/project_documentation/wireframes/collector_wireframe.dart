import 'package:flutter/material.dart';

/// Low-fidelity collector dashboard wireframe (mobile blueprint).
/// Mirrors [CollectorDashboard] section order: header → quick actions → status → search → tasks → activity.
/// No state, no API — white / grey / black only.
class CollectorDashboardWireframe extends StatelessWidget {
  const CollectorDashboardWireframe({super.key});

  static const _sectionGap = 28.0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Hello, [Collector Name]',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Zone: [Zone Name] · [Subtitle]',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: _sectionGap),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _SketchButton(label: '[View Map]'),
                      const SizedBox(width: 10),
                      _SketchButton(label: '[My History]'),
                      const SizedBox(width: 10),
                      _SketchButton(label: '[Notifications]'),
                    ],
                  ),
                ),
                const SizedBox(height: _sectionGap),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 360;
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            flex: 5,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: _ZoneRingSketch(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 6,
                            child: Column(
                              children: [
                                _SketchCard(
                                  lines: const [
                                    '[Bins Cleared]',
                                    '[N]',
                                    '[Today]',
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _SketchCard(
                                  lines: const [
                                    '[Weight Managed]',
                                    '[Total KG]',
                                    '[Formula note]',
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        const _ZoneRingSketch(),
                        const SizedBox(height: 16),
                        _SketchCard(
                          lines: const [
                            '[Bins Cleared]',
                            '[N]',
                            '[Today]',
                          ],
                        ),
                        const SizedBox(height: 12),
                        _SketchCard(
                          lines: const [
                            '[Weight Managed]',
                            '[Total KG]',
                            '[Formula note]',
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: _sectionGap),
                Container(
                  height: 48,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey),
                  ),
                  child: const Text(
                    '[Search field]',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
                const SizedBox(height: _sectionGap),
                const Text(
                  '[Tasks for Today]',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey, width: 2),
                  ),
                  child: const Text(
                    '[Critical / warning task card]',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black, fontSize: 13),
                  ),
                ),
                const SizedBox(height: _sectionGap),
                const Text(
                  '[My Recent Activity]',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '[Recent activity subtitle]',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('[List item 1]', style: TextStyle(color: Colors.black)),
                      SizedBox(height: 8),
                      Text('[List item 2]', style: TextStyle(color: Colors.black)),
                      SizedBox(height: 8),
                      Text('[List item 3]', style: TextStyle(color: Colors.black)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SketchButton extends StatelessWidget {
  final String label;

  const _SketchButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.crop_square, color: Colors.grey, size: 26),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneRingSketch extends StatelessWidget {
  const _ZoneRingSketch();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '[Zone Cleanliness]',
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.grey, width: 10),
          ),
          alignment: Alignment.center,
          child: const Text(
            'X%',
            style: TextStyle(
              color: Colors.black,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _SketchCard extends StatelessWidget {
  final List<String> lines;

  const _SketchCard({required this.lines});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i < lines.length - 1 ? 4 : 0),
              child: Text(
                lines[i],
                style: TextStyle(
                  color: i == 1 ? Colors.black : Colors.grey,
                  fontSize: i == 1 ? 22 : 13,
                  fontWeight: i == 1 ? FontWeight.w800 : FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
