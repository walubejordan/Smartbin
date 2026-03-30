import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../theme/app_colors.dart';

class SmartWasteDashboardTab extends StatelessWidget {
  final String userName;

  const SmartWasteDashboardTab({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 900;

    // Mock data for UI approval. Replace with backend later.
    const totalBins = 12;
    const fullBins = 4;
    const halfFullBins = 4;
    const emptyBins = 4;

    final areas = const [
      'Central',
      'Downtown',
      'Coastal',
      'Commercial',
      'Education'
    ];

    final organic = const [45.0, 22.0, 30.0, 40.0, 18.0];
    final plastic = const [30.0, 38.0, 12.0, 20.0, 25.0];
    final metal = const [12.0, 18.0, 20.0, 16.0, 10.0];
    final mixed = const [7.0, 9.0, 8.0, 15.0, 20.0];

    final days = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final trendGreen = const [44.0, 40.0, 54.0, 48.0, 60.0, 52.0, 46.0];
    final trendBlue = const [45.0, 42.0, 53.0, 46.0, 61.0, 38.0, 30.0];

    final recentAlerts = <_AlertItem>[
      const _AlertItem(
        color: Color(0xFFEF4444),
        title: 'City Park A bin is 95% full',
        timestampLabel: '2 min ago',
      ),
      const _AlertItem(
        color: Color(0xFFF59E0B),
        title: 'Sensor SNS-0424 went offline',
        timestampLabel: '15 min ago',
      ),
      const _AlertItem(
        color: Color(0xFF94A3B8),
        title: 'Missed collection at Mall Entrance',
        timestampLabel: '1 hour ago',
      ),
      const _AlertItem(
        color: Color(0xFFEF4444),
        title: 'Hospital Zone bin is 88% full',
        timestampLabel: '8 min ago',
      ),
    ];

    return RefreshIndicator(
      onRefresh: () async {
        // Mock UI only (no backend connection yet).
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopHeader(context),
            const SizedBox(height: 16),
            _buildStatCards(
              context: context,
              totalBins: totalBins,
              fullBins: fullBins,
              halfFullBins: halfFullBins,
              emptyBins: emptyBins,
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 1050) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildChartsRow(
                        areas: areas,
                        organic: organic,
                        plastic: plastic,
                        metal: metal,
                        mixed: mixed,
                        days: days,
                        trendGreen: trendGreen,
                        trendBlue: trendBlue,
                        isMobile: true,
                      ),
                      const SizedBox(height: 14),
                      _buildRecentAlertsPanel(recentAlerts: recentAlerts),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildChartsRow(
                        areas: areas,
                        organic: organic,
                        plastic: plastic,
                        metal: metal,
                        mixed: mixed,
                        days: days,
                        trendGreen: trendGreen,
                        trendBlue: trendBlue,
                        isMobile: false,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: isMobile ? null : 380,
                      child: _buildRecentAlertsPanel(
                        recentAlerts: recentAlerts,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Good Morning, ${userName.split(' ').first}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Here\'s your collection summary for today',
          style: TextStyle(
            color: AppColors.subText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards({
    required BuildContext context,
    required int totalBins,
    required int fullBins,
    required int halfFullBins,
    required int emptyBins,
  }) {
    final isSmall = MediaQuery.sizeOf(context).width < 900;

    final cards = <Widget>[
      _StatCard(
        color: const Color(0xFF2563EB),
        icon: FontAwesomeIcons.boxesStacked,
        number: '$totalBins',
        label: 'TOTAL BINS',
      ),
      _StatCard(
        color: const Color(0xFFEF4444),
        icon: FontAwesomeIcons.triangleExclamation,
        number: '$fullBins',
        label: 'FULL BINS',
        badgeText: 'Needs attention',
      ),
      _StatCard(
        color: const Color(0xFFFFB300),
        icon: FontAwesomeIcons.paste,
        number: '$halfFullBins',
        label: 'HALF FULL',
      ),
      _StatCard(
        color: const Color(0xFF22C55E),
        icon: FontAwesomeIcons.circleCheck,
        number: '$emptyBins',
        label: 'EMPTY BINS',
      ),
    ];

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: isSmall ? 2 : 4,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      children: cards,
    );
  }

  Widget _buildChartsRow({
    required List<String> areas,
    required List<double> organic,
    required List<double> plastic,
    required List<double> metal,
    required List<double> mixed,
    required List<String> days,
    required List<double> trendGreen,
    required List<double> trendBlue,
    required bool isMobile,
  }) {
    final barCard = _WhiteChartCard(
      title: 'Waste Levels by Area',
      child: SizedBox(
        height: isMobile ? 240 : 260,
        child: BarChart(
          _buildAreaBarChartData(
            areas: areas,
            organic: organic,
            plastic: plastic,
            metal: metal,
            mixed: mixed,
          ),
        ),
      ),
    );

    final lineCard = _WhiteChartCard(
      title: 'Collection Trends (This Week)',
      child: SizedBox(
        height: isMobile ? 240 : 260,
        child: LineChart(
          _buildTrendLineChartData(
            days: days,
            green: trendGreen,
            blue: trendBlue,
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isMobile
            ? Column(
                children: [
                  barCard,
                  const SizedBox(height: 14),
                  lineCard,
                ],
              )
            : Row(
                children: [
                  Expanded(child: barCard),
                  const SizedBox(width: 14),
                  Expanded(child: lineCard),
                ],
              ),
      ],
    );
  }

  Widget _buildRecentAlertsPanel({
    required List<_AlertItem> recentAlerts,
  }) {
    return _WhiteChartCard(
      title: 'Recent Alerts',
      headerRight: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2FE),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${recentAlerts.length} unread',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: Color(0xFF1D4ED8),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          ...recentAlerts.asMap().entries.map((entry) {
            final i = entry.key;
            final alert = entry.value;
            return Column(
              children: [
                if (i != 0) const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin:
                            const EdgeInsets.only(top: 6, left: 2, right: 10),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: alert.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              alert.timestampLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const _NewBadge(),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  BarChartData _buildAreaBarChartData({
    required List<String> areas,
    required List<double> organic,
    required List<double> plastic,
    required List<double> metal,
    required List<double> mixed,
  }) {
    const green = Color(0xFF4CAF50);
    const blue = Color(0xFF2563EB);
    const amber = Color(0xFFFFB300);
    const gray = Color(0xFF6B7280);

    return BarChartData(
      maxY: 60,
      barGroups: List.generate(areas.length, (i) {
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: organic[i],
              color: green,
              width: 10,
              borderRadius: BorderRadius.circular(4),
            ),
            BarChartRodData(
              toY: plastic[i],
              color: blue,
              width: 10,
              borderRadius: BorderRadius.circular(4),
            ),
            BarChartRodData(
              toY: metal[i],
              color: amber,
              width: 10,
              borderRadius: BorderRadius.circular(4),
            ),
            BarChartRodData(
              toY: mixed[i],
              color: gray,
              width: 10,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      }),
      gridData: FlGridData(
        show: true,
        horizontalInterval: 15,
        getDrawingHorizontalLine: (value) => const FlLine(
          color: Color(0xFFE5E7EB),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 15,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= areas.length)
                return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  areas[idx],
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
    );
  }

  LineChartData _buildTrendLineChartData({
    required List<String> days,
    required List<double> green,
    required List<double> blue,
  }) {
    const axisGray = Color(0xFFCBD5E1);

    return LineChartData(
      minY: 0,
      maxY: 70,
      gridData: FlGridData(
        show: true,
        horizontalInterval: 15,
        getDrawingHorizontalLine: (value) => const FlLine(
          color: Color(0xFFE5E7EB),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(
        show: false,
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: false,
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
              return Text(
                days[idx],
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: List.generate(
              green.length, (i) => FlSpot(i.toDouble(), green[i])),
          isCurved: true,
          color: AppColors.primaryGreen,
          barWidth: 3.5,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 3.5,
                color: AppColors.primaryGreen,
                strokeWidth: 0,
              );
            },
          ),
        ),
        LineChartBarData(
          spots:
              List.generate(blue.length, (i) => FlSpot(i.toDouble(), blue[i])),
          isCurved: true,
          color: const Color(0xFF2563EB),
          barWidth: 3.5,
          dashArray: [8, 5],
          dotData: FlDotData(show: false),
        ),
      ],
    );
  }
}

class _WhiteChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? headerRight;

  const _WhiteChartCard({
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
                    height: 1.2,
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

class _StatCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String number;
  final String label;
  final String? badgeText;

  const _StatCard({
    required this.color,
    required this.icon,
    required this.number,
    required this.label,
    this.badgeText,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            number,
            style: const TextStyle(
              fontSize: 26,
              height: 1,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          if (badgeText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badgeText!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Color(0xFF1D4ED8),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _AlertItem {
  final Color color;
  final String title;
  final String timestampLabel;

  const _AlertItem({
    required this.color,
    required this.title,
    required this.timestampLabel,
  });
}
