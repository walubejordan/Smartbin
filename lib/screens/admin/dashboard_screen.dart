import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/bin_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

/// Admin overview: summary cards, zone health, and a merged collections + notifications feed.
class AdminDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onAddBin;
  final VoidCallback? onAssign;
  final VoidCallback? onReports;
  final VoidCallback? onDownloadReport;

  const AdminDashboardScreen({
    super.key,
    required this.user,
    this.onAddBin,
    this.onAssign,
    this.onReports,
    this.onDownloadReport,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<BinModel> _bins = [];
  List<_FeedItem> _feed = [];
  bool _loading = true;
  String? _error;
  String? _feedNote;

  /// Bins still at fill ≥ 90% (critical waste pending).
  int _criticalRemaining = 0;

  /// Distinct bins cleared today from ≥90% fill (from collection history).
  int _criticalClearedToday = 0;

  /// Cleared / (cleared + remaining), for circular progress.
  double _criticalProgressFraction = 0;

  static const double _shortcutToSummaryGap = 20;
  static const double _sectionGap = 28;

  static const double _criticalFillThreshold = 90;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _feedNote = null;
    });
    final api = Provider.of<ApiService>(context, listen: false);

    List<dynamic> rawBins = [];
    List<dynamic> rawCollections = [];
    Map<String, dynamic>? notifResponse;

    try {
      rawBins = await api.getBins();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      return;
    }

    try {
      final results = await Future.wait([
        api.getRecentCollections(limit: 120),
        api.getNotifications(limit: 10),
      ]);
      rawCollections = results[0] as List<dynamic>;
      notifResponse = results[1] as Map<String, dynamic>;
    } catch (e) {
      _feedNote = 'Some activity could not be loaded: $e';
      try {
        notifResponse = await api.getNotifications(limit: 10);
      } catch (_) {
        notifResponse = {'data': <dynamic>[]};
      }
    }

    if (!mounted) return;

    final bins = BinModel.listFromDynamic(rawBins);
    final notifList = List<dynamic>.from(notifResponse['data'] ?? []);
    final forFeed = rawCollections.length > 10
        ? rawCollections.sublist(0, 10)
        : List<dynamic>.from(rawCollections);
    final feed = _mergeFeed(forFeed, notifList);
    final progress = _criticalProgressFrom(bins, rawCollections);

    setState(() {
      _bins = bins;
      _feed = feed;
      _criticalRemaining = progress.remaining;
      _criticalClearedToday = progress.clearedToday;
      _criticalProgressFraction = progress.fraction;
      _loading = false;
    });
  }

  /// Critical = fill ≥ 90%. Progress = cleared today (fill_before ≥ 90) vs still pending.
  static _CriticalDayProgress _criticalProgressFrom(
    List<BinModel> bins,
    List<dynamic> collections,
  ) {
    final remaining =
        bins.where((b) => b.fillLevel >= _criticalFillThreshold).length;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final clearedIds = <int>{};

    for (final e in collections) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final t = _parseTime(m['collection_time']);
      if (t == null) continue;
      final day = DateTime(t.year, t.month, t.day);
      if (day != todayStart) continue;

      final before = m['fill_level_before'];
      final fb = before is num
          ? before.toDouble()
          : double.tryParse('$before') ?? 0;
      if (fb < _criticalFillThreshold) continue;

      final bid = m['bin_id'];
      final id = bid is int ? bid : int.tryParse('$bid');
      if (id != null) clearedIds.add(id);
    }

    final cleared = clearedIds.length;
    final denom = cleared + remaining;
    final fraction = denom <= 0 ? 1.0 : (cleared / denom).clamp(0.0, 1.0);
    return _CriticalDayProgress(
      remaining: remaining,
      clearedToday: cleared,
      fraction: fraction,
    );
  }

  static DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  static String _timeAgo(DateTime? t) {
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min${diff.inMinutes == 1 ? '' : 's'} ago';
    if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    return '${t.day}/${t.month}/${t.year}';
  }

  static List<_FeedItem> _mergeFeed(
    List<dynamic> collections,
    List<dynamic> notifications,
  ) {
    final items = <_FeedItem>[];

    for (final e in collections) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final at = _parseTime(m['collection_time']);
      final code = m['bin_code']?.toString() ?? 'Bin';
      final loc = m['location_name']?.toString() ?? '';
      final collector = m['collector_name']?.toString() ?? '';
      final subtitle = [
        if (loc.isNotEmpty) loc,
        if (collector.isNotEmpty) 'by $collector',
      ].join(' · ');
      items.add(
        _FeedItem(
          at: at,
          icon: Icons.check_circle,
          iconColor: AppColors.primaryGreen,
          title: 'Collection: $code',
          subtitle: subtitle.isEmpty ? 'Pickup recorded' : subtitle,
        ),
      );
    }

    for (final e in notifications) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final at = _parseTime(m['created_at']);
      final type = m['type']?.toString() ?? 'info';
      final title = m['title']?.toString() ?? 'Notification';
      final message = m['message']?.toString() ?? '';
      final binCode = m['bin_code']?.toString();
      IconData icon;
      Color color;
      switch (type) {
        case 'critical':
          icon = Icons.warning_rounded;
          color = Colors.red.shade700;
          break;
        case 'warning':
          icon = Icons.warning_amber_rounded;
          color = Colors.orange.shade800;
          break;
        case 'success':
          icon = Icons.check_circle_outline;
          color = AppColors.primaryGreen;
          break;
        default:
          icon = Icons.notifications_active_outlined;
          color = Colors.blue.shade700;
      }
      final sub = [
        if (message.isNotEmpty) message,
        if (binCode != null && binCode.isNotEmpty) 'Bin $binCode',
      ].join(' · ');
      items.add(
        _FeedItem(
          at: at,
          icon: icon,
          iconColor: color,
          title: title,
          subtitle: sub.isEmpty ? type : sub,
        ),
      );
    }

    items.sort((a, b) {
      final ta = a.at;
      final tb = b.at;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    if (items.length > 10) {
      return items.sublist(0, 10);
    }
    return items;
  }

  List<({String name, double avgFill, int count})> get _zones {
    final map = <String, List<BinModel>>{};
    for (final b in _bins) {
      final z = (b.zone != null && b.zone!.trim().isNotEmpty)
          ? b.zone!.trim()
          : 'Unassigned';
      map.putIfAbsent(z, () => []).add(b);
    }
    final out = map.entries.map((e) {
      final fills = e.value.map((b) => b.fillLevel);
      final avg = fills.isEmpty ? 0.0 : fills.reduce((a, b) => a + b) / fills.length;
      return (name: e.key, avgFill: avg, count: e.value.length);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  Color _fillColor(double pct) {
    if (pct >= 80) return Colors.red.shade600;
    if (pct >= 60) return Colors.orange.shade700;
    return AppColors.primaryGreen;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 900;
        final crossAxisCount = wide ? 4 : 1;
        final total = _bins.length;
        final critical = _bins.where((b) => b.isCritical).length;
        final warning = _bins.where((b) => b.isWarning && !b.isCritical).length;
        final normal = total - critical - warning;
        final avgFill = total == 0
            ? 0.0
            : _bins.map((b) => b.fillLevel).reduce((a, b) => a + b) / total;

        final zoneSection = _ZoneHealthCard(
          zones: _zones,
          fillColor: _fillColor,
        );
        final feedSection = _RecentActivityCard(
          items: _feed,
          timeAgo: _timeAgo,
          note: _feedNote,
        );
        final progressCard = _CriticalProgressCard(
          fraction: _criticalProgressFraction,
          remaining: _criticalRemaining,
          clearedToday: _criticalClearedToday,
        );
        final showShortcuts = widget.onAddBin != null ||
            widget.onAssign != null ||
            widget.onReports != null ||
            widget.onDownloadReport != null;

        return RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Hello, ${widget.user['name'] ?? 'there'}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Organization overview (live from bins API)',
                    style: TextStyle(color: AppColors.subText),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null)
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                    ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    if (showShortcuts) ...[
                      _DashboardShortcutsRow(
                        onAddBin: widget.onAddBin,
                        onAssign: widget.onAssign,
                        onReports: widget.onReports,
                        onDownloadReport: widget.onDownloadReport,
                      ),
                      const SizedBox(height: _shortcutToSummaryGap),
                    ],
                    GridView.count(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: crossAxisCount == 1 ? 2.4 : 1.15,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _StatCard(
                          title: 'Total bins',
                          value: '$total',
                          icon: Icons.delete_outline,
                          color: AppColors.primaryGreen,
                        ),
                        _StatCard(
                          title: 'Critical / full',
                          value: '$critical',
                          icon: Icons.warning_amber_rounded,
                          color: Colors.red.shade700,
                        ),
                        _StatCard(
                          title: 'Warning',
                          value: '$warning',
                          icon: Icons.info_outline,
                          color: Colors.orange.shade800,
                        ),
                        _StatCard(
                          title: 'Avg fill %',
                          value: avgFill.toStringAsFixed(0),
                          icon: Icons.analytics_outlined,
                          color: Colors.blue.shade700,
                          subtitle: 'Normal status: $normal',
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
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                zoneSection,
                                const SizedBox(height: 16),
                                progressCard,
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: feedSection),
                        ],
                      )
                    else ...[
                      zoneSection,
                      const SizedBox(height: 16),
                      progressCard,
                      const SizedBox(height: 16),
                      feedSection,
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CriticalDayProgress {
  final int remaining;
  final int clearedToday;
  final double fraction;

  const _CriticalDayProgress({
    required this.remaining,
    required this.clearedToday,
    required this.fraction,
  });
}

class _DashboardShortcutsRow extends StatelessWidget {
  final VoidCallback? onAddBin;
  final VoidCallback? onAssign;
  final VoidCallback? onReports;
  final VoidCallback? onDownloadReport;

  const _DashboardShortcutsRow({
    required this.onAddBin,
    required this.onAssign,
    required this.onReports,
    required this.onDownloadReport,
  });

  static const double _tileMinWidth = 112;

  @override
  Widget build(BuildContext context) {
    final entries = <({String label, IconData icon, VoidCallback onTap})>[];
    if (onAddBin != null) {
      entries.add((
        label: 'Add Bin',
        icon: Icons.add_circle_outline,
        onTap: onAddBin!,
      ));
    }
    if (onAssign != null) {
      entries.add((
        label: 'Assign',
        icon: Icons.person_add_alt_1_outlined,
        onTap: onAssign!,
      ));
    }
    if (onDownloadReport != null) {
      entries.add((
        label: 'Download Report',
        icon: Icons.picture_as_pdf_outlined,
        onTap: onDownloadReport!,
      ));
    }
    if (onReports != null) {
      entries.add((
        label: 'Reports',
        icon: Icons.insights_outlined,
        onTap: onReports!,
      ));
    }

    if (entries.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 560;
        final rowChildren = <Widget>[];
        for (var i = 0; i < entries.length; i++) {
          if (i > 0) rowChildren.add(const SizedBox(width: 10));
          final e = entries[i];
          final tile = _DashboardShortcutTile(
            label: e.label,
            icon: e.icon,
            onTap: e.onTap,
          );
          if (narrow) {
            rowChildren.add(
              SizedBox(width: _tileMinWidth, child: tile),
            );
          } else {
            rowChildren.add(Expanded(child: tile));
          }
        }

        if (narrow) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: rowChildren),
          );
        }
        return Row(children: rowChildren);
      },
    );
  }
}

class _DashboardShortcutTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _DashboardShortcutTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: AppColors.cardShadow.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: AppColors.cardBackground,
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.primaryGreen.withValues(alpha: 0.28),
          highlightColor: AppColors.primaryGreen.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.primaryGreen, size: 28),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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

class _CriticalProgressCard extends StatelessWidget {
  final double fraction;
  final int remaining;
  final int clearedToday;

  const _CriticalProgressCard({
    required this.fraction,
    required this.remaining,
    required this.clearedToday,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (fraction * 100).round().clamp(0, 100);
    final denom = clearedToday + remaining;
    final subtext = denom == 0
        ? 'No critical bins requiring clearance right now.'
        : '$remaining bin${remaining == 1 ? '' : 's'} remaining to reach 100% target.';

    return Card(
      elevation: 2,
      shadowColor: AppColors.cardShadow.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardRadius),
      ),
      color: AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Collection progress',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Critical waste (fill ≥ 90%) cleared today vs still pending',
              style: TextStyle(fontSize: 12, color: AppColors.subText),
            ),
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                width: 176,
                height: 176,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 176,
                      height: 176,
                      child: CircularProgressIndicator(
                        value: fraction.clamp(0.0, 1.0),
                        strokeWidth: 14,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.grey.shade200,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$pct%',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'of Critical Waste Cleared Today',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.25,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              subtext,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.subText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedItem {
  final DateTime? at;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  _FeedItem({
    required this.at,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: AppColors.cardShadow.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardRadius),
      ),
      color: AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.subText,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.subText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoneHealthCard extends StatelessWidget {
  final List<({String name, double avgFill, int count})> zones;
  final Color Function(double pct) fillColor;

  const _ZoneHealthCard({
    required this.zones,
    required this.fillColor,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Zone health',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Average fill level by zone',
              style: TextStyle(color: AppColors.subText, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (zones.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No bins loaded yet.',
                  style: TextStyle(color: AppColors.subText),
                ),
              )
            else
              ...zones.map((z) {
                final v = (z.avgFill / 100).clamp(0.0, 1.0);
                final barColor = fillColor(z.avgFill);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Zone status: ${z.name}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            '${z.avgFill.round()}% avg · ${z.count} bin${z.count == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: AppColors.subText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: v,
                          minHeight: 10,
                          backgroundColor: Colors.grey.shade200,
                          color: barColor,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  final List<_FeedItem> items;
  final String Function(DateTime?) timeAgo;
  final String? note;

  const _RecentActivityCard({
    required this.items,
    required this.timeAgo,
    this.note,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Recent activity',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Live feed from collections and notifications',
              style: TextStyle(color: AppColors.subText, fontSize: 13),
            ),
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(
                note!,
                style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
              ),
            ],
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No recent activity.',
                  style: TextStyle(color: AppColors.subText),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Colors.grey.shade200,
                ),
                itemBuilder: (context, i) {
                  final it = items[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(it.icon, color: it.iconColor, size: 26),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                it.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              if (it.subtitle.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  it.subtitle,
                                  style: const TextStyle(
                                    color: AppColors.subText,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeAgo(it.at),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
