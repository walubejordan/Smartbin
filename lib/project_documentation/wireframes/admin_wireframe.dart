import 'package:flutter/material.dart';

/// Low-fidelity admin dashboard wireframe (design phase).
/// Mirrors [AdminDashboardScreen] layout: permanent sidebar + summary grid + zone + progress + feed.
/// No state, no API — white / grey / black only.
class AdminDashboardWireframe extends StatelessWidget {
  const AdminDashboardWireframe({super.key});

  static const _gap = 20.0;
  static const _sectionGap = 28.0;

  BoxDecoration get _box => BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
      );

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 240,
            child: ColoredBox(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Row(
                      children: [
                        _GreyCircle(size: 40),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '[App Name]',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '[Admin Name]',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.grey),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: const [
                        _NavRow(label: '[Nav: Home]'),
                        _NavRow(label: '[Nav: Bins]'),
                        _NavRow(label: '[Nav: Map]'),
                        _NavRow(label: '[Nav: Alerts]'),
                        _NavRow(label: '[Nav: Team]'),
                        _NavRow(label: '[Nav: Stats]'),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.grey),
                  const _NavRow(label: '[Nav: Settings]'),
                  const _NavRow(label: '[Nav: Log out]'),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1, color: Colors.grey),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey),
                    ),
                  ),
                  child: const Text(
                    '[Screen Title: Dashboard]',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 900;
                      final crossAxisCount = wide ? 4 : 1;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minWidth: constraints.maxWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Hello, [Admin Name]',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '[Organization overview line]',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                              const SizedBox(height: _gap),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _ShortcutTile(
                                      label: '[Add Bin]',
                                      decoration: _box,
                                    ),
                                    const SizedBox(width: 10),
                                    _ShortcutTile(
                                      label: '[Assign]',
                                      decoration: _box,
                                    ),
                                    const SizedBox(width: 10),
                                    _ShortcutTile(
                                      label: '[Download Report]',
                                      decoration: _box,
                                    ),
                                    const SizedBox(width: 10),
                                    _ShortcutTile(
                                      label: '[Reports]',
                                      decoration: _box,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: _gap),
                              GridView.count(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: crossAxisCount == 1 ? 2.4 : 1.15,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                                  _StatWire(
                                    title: '[Total bins]',
                                    value: '[N]',
                                    decoration: _box,
                                  ),
                                  _StatWire(
                                    title: '[Critical / full]',
                                    value: '[N]',
                                    decoration: _box,
                                  ),
                                  _StatWire(
                                    title: '[Warning]',
                                    value: '[N]',
                                    decoration: _box,
                                  ),
                                  _StatWire(
                                    title: '[Avg fill %]',
                                    value: '[N]',
                                    subtitle: '[Normal count]',
                                    decoration: _box,
                                  ),
                                ],
                              ),
                              const SizedBox(height: _sectionGap),
                              if (wide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _Panel(
                                            title: '[Zone health]',
                                            subtitle: '[Avg fill by zone]',
                                            body: '[Zone list / chart area]',
                                            decoration: _box,
                                          ),
                                          const SizedBox(height: 16),
                                          _Panel(
                                            title: '[Critical progress]',
                                            subtitle: '[Day target copy]',
                                            body:
                                                '[Circular progress placeholder]',
                                            decoration: _box,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _Panel(
                                        title: '[Recent activity]',
                                        subtitle: '[Feed subtitle]',
                                        body: '[Recent Activity List]',
                                        decoration: _box,
                                        minHeight: 320,
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                _Panel(
                                  title: '[Zone health]',
                                  subtitle: '[Avg fill by zone]',
                                  body: '[Zone list / chart area]',
                                  decoration: _box,
                                ),
                                const SizedBox(height: 16),
                                _Panel(
                                  title: '[Critical progress]',
                                  subtitle: '[Day target copy]',
                                  body: '[Circular progress placeholder]',
                                  decoration: _box,
                                ),
                                const SizedBox(height: 16),
                                _Panel(
                                  title: '[Recent activity]',
                                  subtitle: '[Feed subtitle]',
                                  body: '[Recent Activity List]',
                                  decoration: _box,
                                  minHeight: 280,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final String label;

  const _NavRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          color: Colors.white,
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.black, fontSize: 14),
        ),
      ),
    );
  }
}

class _GreyCircle extends StatelessWidget {
  final double size;

  const _GreyCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.grey,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  final String label;
  final BoxDecoration decoration;

  const _ShortcutTile({
    required this.label,
    required this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: decoration,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.crop_square, color: Colors.grey, size: 28),
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
      ),
    );
  }
}

class _StatWire extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final BoxDecoration decoration;

  const _StatWire({
    required this.title,
    required this.value,
    required this.decoration,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: decoration,
      child: Row(
        children: [
          Icon(Icons.crop_square, size: 36, color: Colors.grey),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String subtitle;
  final String body;
  final BoxDecoration decoration;
  final double? minHeight;

  const _Panel({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.decoration,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            constraints: BoxConstraints(minHeight: minHeight ?? 100),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              color: Colors.white,
            ),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
