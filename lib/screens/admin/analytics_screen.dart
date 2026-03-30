import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/weekly_report_download.dart';
import '../../theme/app_colors.dart';

/// Admin analytics: impact metrics, 7-day bar chart, top collectors.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const Color _barColor = AppColors.primaryGreen;
  static const double _kgPerFillPoint = 0.5;

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  bool _barsRevealed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _barsRevealed = false;
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final summary = await api.getAnalyticsSummary();
      if (!mounted) return;
      setState(() {
        _data = summary;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _barsRevealed = true);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
        _data = null;
      });
    }
  }

  /// Last 7 calendar days (oldest → newest) with merged API totals (fill index cleared).
  List<({DateTime day, double fillTotal, double kgDay})> _sevenDaySeries() {
    final daily = _data?['daily_volume'];
    final map = <String, double>{};
    if (daily is List) {
      for (final e in daily) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final ds = m['date']?.toString();
        final v = m['total_fill_cleared'];
        if (ds == null || ds.length < 10) continue;
        final key = ds.substring(0, 10);
        map[key] = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
      }
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final fill = map[key] ?? 0;
      final kg = fill * _kgPerFillPoint;
      return (day: day, fillTotal: fill, kgDay: kg);
    });
  }

  String _peakWeekdayLabel(List<({DateTime day, double fillTotal, double kgDay})> series) {
    if (series.every((e) => e.fillTotal <= 0)) return '—';
    var best = series.first;
    for (final e in series.skip(1)) {
      if (e.fillTotal > best.fillTotal) best = e;
    }
    return DateFormat('EEEE').format(best.day);
  }

  String _formatKg(num kg) {
    final fmt = NumberFormat.decimalPattern();
    return '${fmt.format(kg.round())} KG';
  }

  Map<String, dynamic>? get _impact {
    final t = _data?['total_impact'];
    if (t is Map<String, dynamic>) return t;
    if (t is Map) return Map<String, dynamic>.from(t);
    return null;
  }

  List<Map<String, dynamic>> _leaderboard() {
    final raw = _data?['collector_leaderboard'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final series = _sevenDaySeries();
    final maxY = series.map((e) => e.kgDay).fold<double>(0, (a, b) => a > b ? a : b);
    final chartMaxY = maxY <= 0 ? 10.0 : (maxY * 1.15).clamp(5.0, double.infinity);

    final impact = _impact;
    final estimatedKg = (impact?['estimated_kg'] is num)
        ? (impact!['estimated_kg'] as num).toDouble()
        : double.tryParse('${impact?['estimated_kg']}') ?? 0;
    final avgFill = (impact?['avg_fill_at_collection'] is num)
        ? (impact!['avg_fill_at_collection'] as num).toDouble()
        : double.tryParse('${impact?['avg_fill_at_collection']}') ?? 0;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white24
        : Colors.grey.shade300.withValues(alpha: 0.5);

    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Analytics',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Impact and activity from live API data',
                              style: TextStyle(
                                color: AppColors.subText,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: () => downloadWeeklyReportPdf(context),
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                        label: const Text('Download PDF'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              _error!,
                              style: TextStyle(color: Colors.red.shade900),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    _impactGrid(
                      context,
                      totalKg: estimatedKg,
                      peakDay: _peakWeekdayLabel(series),
                      avgFill: avgFill,
                    ),
                    const SizedBox(height: 24),
                    _weeklyBarCard(context, series, chartMaxY, borderColor),
                    const SizedBox(height: 24),
                    _collectorRankingCard(context, _leaderboard()),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _impactGrid(
    BuildContext context, {
    required double totalKg,
    required String peakDay,
    required double avgFill,
  }) {
    final wide = MediaQuery.sizeOf(context).width > 720;
    final cards = [
      _ImpactCard(
        title: 'Total waste managed',
        value: _formatKg(totalKg),
        subtitle: 'Lifetime estimate (0.5 kg per fill point)',
        icon: Icons.scale_outlined,
      ),
      _ImpactCard(
        title: 'Peak day',
        value: peakDay,
        subtitle: 'Highest cleared volume in the last 7 days',
        icon: Icons.trending_up,
      ),
      _ImpactCard(
        title: 'Avg fill at collection',
        value: '${avgFill.round()}%',
        subtitle: 'Mean fill_level_before when bins were cleared',
        icon: Icons.percent,
      ),
      _ImpactCard(
        title: 'System uptime',
        value: '99.9%',
        subtitle: 'Service availability target (rolling)',
        icon: Icons.cloud_done_outlined,
      ),
    ];

    if (wide) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 12),
              Expanded(child: cards[3]),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          cards[i],
        ],
      ],
    );
  }

  Widget _weeklyBarCard(
    BuildContext context,
    List<({DateTime day, double fillTotal, double kgDay})> series,
    double chartMaxY,
    Color borderColor,
  ) {
    final axisLabelStyle = TextStyle(
      fontSize: 11,
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.white70
          : Colors.grey.shade700,
    );

    return Card(
      elevation: 2,
      shadowColor: AppColors.cardShadow.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardRadius),
      ),
      color: AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Waste cleared (last 7 days)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Estimated kg emptied per day (${_kgPerFillPoint} kg × fill index)',
              style: const TextStyle(fontSize: 12, color: AppColors.subText),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1.55,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: BarChart(
                  BarChartData(
                    minY: 0,
                    maxY: chartMaxY,
                    alignment: BarChartAlignment.spaceAround,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => Colors.blueGrey.shade800,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final i = group.x.toInt();
                          if (i < 0 || i >= series.length) return null;
                          final s = series[i];
                          final label = DateFormat('EEE d MMM').format(s.day);
                          return BarTooltipItem(
                            label,
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            children: [
                              TextSpan(
                                text:
                                    '\n${s.kgDay.toStringAsFixed(1)} kg\n(${s.fillTotal.toStringAsFixed(0)} fill index)',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= series.length) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              meta: meta,
                              space: 6,
                              child: Text(
                                DateFormat('EEE').format(series[i].day),
                                style: axisLabelStyle,
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          interval: chartMaxY > 50 ? 20 : 5,
                          getTitlesWidget: (value, meta) {
                            if (value < 0 || value > chartMaxY) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              meta: meta,
                              space: 6,
                              child: Text(
                                value >= 1000
                                    ? '${(value / 1000).toStringAsFixed(1)}k'
                                    : value.toStringAsFixed(0),
                                style: axisLabelStyle,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: borderColor.withValues(alpha: 0.35),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        bottom: BorderSide(color: borderColor),
                        left: BorderSide(color: borderColor),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < series.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: _barsRevealed ? series[i].kgDay : 0,
                              color: _barColor,
                              width: 18,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: chartMaxY,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.grey.shade200,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _collectorRankingCard(
    BuildContext context,
    List<Map<String, dynamic>> rows,
  ) {
    return Card(
      elevation: 2,
      shadowColor: AppColors.cardShadow.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardRadius),
      ),
      color: AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Collector ranking',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Top 3 by total collections (clears)',
                style: TextStyle(fontSize: 12, color: AppColors.subText),
              ),
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No collection history yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.subText),
                ),
              )
            else
              ...List.generate(rows.length, (index) {
                final r = rows[index];
                final name = r['name']?.toString() ?? 'Collector';
                final count = r['collection_count'];
                final n = count is num ? count.toInt() : int.tryParse('$count') ?? 0;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        AppColors.primaryGreen.withValues(alpha: 0.15),
                    foregroundColor: AppColors.primaryGreen,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  title: Text(name),
                  subtitle: Text(
                    n == 1 ? '1 clear' : '$n clears',
                    style: const TextStyle(color: AppColors.subText),
                  ),
                  trailing: Text(
                    '#${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade600,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ImpactCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _ImpactCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: AppColors.cardShadow.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardRadius),
      ),
      color: AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: AppColors.primaryGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.subText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
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
