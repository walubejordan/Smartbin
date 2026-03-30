import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../theme/app_colors.dart';

class SmartWasteCollectorDashboardTab extends StatelessWidget {
  final String userName;

  const SmartWasteCollectorDashboardTab({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 900;

    // Mock data for UI approval.
    const assigned = 5;
    const pending = 3;
    const done = 3;

    final priority = const <_PriorityBin>[
      _PriorityBin(code: 'BIN-001', location: 'City Park A', fillPercent: 96),
      _PriorityBin(code: 'BIN-004', location: 'Hospital Zone', fillPercent: 88),
      _PriorityBin(
          code: 'BIN-012', location: 'Sports Complex', fillPercent: 100),
      _PriorityBin(
          code: 'BIN-088', location: 'Residential Block', fillPercent: 76),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WelcomeBanner(userName: userName),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isMobile ? 1 : 3,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: isMobile ? 3.6 : 2.8,
            children: const [
              _MetricCard(
                label: 'Assigned',
                value: '$assigned',
                icon: FontAwesomeIcons.listCheck,
                color: Color(0xFF2563EB),
              ),
              _MetricCard(
                label: 'Pending',
                value: '$pending',
                icon: FontAwesomeIcons.triangleExclamation,
                color: Color(0xFFF59E0B),
              ),
              _MetricCard(
                label: 'Done',
                value: '$done',
                icon: FontAwesomeIcons.circleCheck,
                color: Color(0xFF22C55E),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _WhiteCard(
            title: 'Priority Collections',
            headerRight: Text(
              '${priority.length} bins',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 6),
                ...priority.asMap().entries.map((entry) {
                  final i = entry.key;
                  final bin = entry.value;
                  return Column(
                    children: [
                      if (i != 0) const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                FontAwesomeIcons.trash,
                                size: 16,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        bin.location,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        bin.code,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF94A3B8),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to open details',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${bin.fillPercent}%',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: _fillColor(bin.fillPercent),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  static Color _fillColor(int percent) {
    if (percent >= 90) return const Color(0xFFEF4444);
    if (percent >= 70) return const Color(0xFFF59E0B);
    return const Color(0xFF22C55E);
  }
}

class _WelcomeBanner extends StatelessWidget {
  final String userName;

  const _WelcomeBanner({required this.userName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen.withOpacity(0.95),
            const Color(0xFF16A34A).withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, ${userName.split(' ').first}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Here\'s your collection summary for today',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withOpacity(0.18),
            child: const Icon(
              FontAwesomeIcons.truckFast,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? headerRight;

  const _WhiteCard({
    required this.title,
    required this.child,
    this.headerRight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (headerRight != null) headerRight!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
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

class _PriorityBin {
  final String code;
  final String location;
  final int fillPercent;

  const _PriorityBin({
    required this.code,
    required this.location,
    required this.fillPercent,
  });
}
