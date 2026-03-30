import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/bin_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

/// Collector home: zone-filtered bins, prioritized tasks, maps link, search.
class CollectorDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onOpenMap;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenAlerts;

  const CollectorDashboard({
    super.key,
    required this.user,
    this.onOpenMap,
    this.onOpenHistory,
    this.onOpenAlerts,
  });

  @override
  State<CollectorDashboard> createState() => _CollectorDashboardState();
}

class _CollectorDashboardState extends State<CollectorDashboard> {
  final TextEditingController _searchCtrl = TextEditingController();

  List<BinModel> _allBins = [];
  List<dynamic> _myHistory = [];
  bool _loading = true;
  String? _error;

  static const double _pendingFillThreshold = 70;
  static const double _sectionGap = 28;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _userZone {
    for (final key in ['zone', 'assigned_zone', 'region']) {
      final v = widget.user[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return widget.user['phone']?.toString().trim() ?? '';
  }

  String get _zoneLabel =>
      _userZone.isNotEmpty ? _userZone : 'your assigned route';

  int? get _collectorId {
    final id = widget.user['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return int.tryParse('$id');
  }

  /// Bins in scope: [BinModel.zone] matches collector zone when both set;
  /// if API omits bin zones, falls back to [BinModel.assignedTo] == collector.
  List<BinModel> _binsInZone(List<BinModel> all) {
    final zone = _userZone;
    final uid = _collectorId;
    final anyBinHasZone = all.any((b) => (b.zone ?? '').trim().isNotEmpty);

    return all.where((b) {
      final bz = (b.zone ?? '').trim();
      if (zone.isNotEmpty) {
        if (bz.isNotEmpty) {
          return bz.toLowerCase() == zone.toLowerCase();
        }
        if (!anyBinHasZone && uid != null && b.assignedTo == uid) {
          return true;
        }
        return false;
      }
      if (uid != null) return b.assignedTo == uid;
      return false;
    }).toList();
  }

  List<BinModel> _applySearch(List<BinModel> bins) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return bins;
    return bins
        .where(
          (b) =>
              b.binCode.toLowerCase().contains(q) ||
              b.location.toLowerCase().contains(q) ||
              (b.zone ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  List<BinModel> _activeTasks(List<BinModel> visible) {
    final tasks =
        visible.where((b) => b.fillLevel >= _pendingFillThreshold).toList();
    tasks.sort((a, b) {
      final ac = a.isCritical;
      final bc = b.isCritical;
      if (ac != bc) return ac ? -1 : 1;
      final aw = a.isWarning && !a.isCritical;
      final bw = b.isWarning && !b.isCritical;
      if (aw != bw) return aw ? -1 : 1;
      return b.fillLevel.compareTo(a.fillLevel);
    });
    return tasks;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final raw = await api.getBins();
      if (!mounted) return;
      setState(() {
        _allBins = BinModel.listFromDynamic(raw);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      return;
    }

    try {
      final hist = await api.getCollectionHistory();
      if (!mounted) return;
      setState(() {
        _myHistory = hist;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _myHistory = [];
        _loading = false;
      });
    }
  }

  static DateTime? _parseCollectionTime(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  static bool _isSameLocalDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Today's clears and estimated kg (sum of fill_level_before × 0.5).
  static ({int clearsToday, double kgToday}) _todayImpact(List<dynamic> history) {
    final now = DateTime.now();
    var clears = 0;
    var totalFill = 0.0;
    for (final e in history) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final t = _parseCollectionTime(m['collection_time']);
      if (t == null || !_isSameLocalDay(t, now)) continue;
      clears++;
      final before = m['fill_level_before'];
      final fb = before is num
          ? before.toDouble()
          : double.tryParse('$before') ?? 0.0;
      totalFill += fb.clamp(0, 100);
    }
    return (clearsToday: clears, kgToday: totalFill * 0.5);
  }

  /// Share of zone bins that are not critical (fill/status). Empty zone → 0.
  static double _zoneCleanlinessFraction(List<BinModel> zoneBins) {
    if (zoneBins.isEmpty) return 0.0;
    final clean = zoneBins.where((b) => !b.isCritical).length;
    return (clean / zoneBins.length).clamp(0.0, 1.0);
  }

  Future<void> _openMaps(BinModel b) async {
    final lat = b.latitude;
    final lng = b.longitude;
    if (lat == null || lng == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No coordinates available for this bin.'),
        ),
      );
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    try {
      if (kIsWeb) {
        await launchUrl(uri, webOnlyWindowName: '_blank');
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open maps: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final zoneBins = _binsInZone(_allBins);
        final pendingInZone =
            zoneBins.where((b) => b.fillLevel >= _pendingFillThreshold).length;
        final visible = _applySearch(zoneBins);
        final activeTasks = _activeTasks(visible);
        final restBins = visible
            .where((b) => b.fillLevel < _pendingFillThreshold)
            .toList()
          ..sort((a, b) => a.binCode.compareTo(b.binCode));
        final allClearInZone = !_loading &&
            _error == null &&
            zoneBins.isNotEmpty &&
            pendingInZone == 0;
        final emptyZone =
            !_loading && _error == null && zoneBins.isEmpty;
        final searchTrim = _searchCtrl.text.trim();
        final searchHidesPendingTasks = pendingInZone > 0 &&
            activeTasks.isEmpty &&
            searchTrim.isNotEmpty &&
            visible.isNotEmpty;
        final todayImpact = _todayImpact(_myHistory);
        final zoneCleanFraction = _zoneCleanlinessFraction(zoneBins);

        return RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Hello, ${widget.user['name'] ?? 'Collector'}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userZone.isNotEmpty
                        ? 'Zone: $_userZone · smart task list'
                        : 'Assigned bins · smart task list',
                    style: const TextStyle(color: AppColors.subText),
                  ),
                  const SizedBox(height: _sectionGap),
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
                    if (widget.onOpenMap != null ||
                        widget.onOpenHistory != null ||
                        widget.onOpenAlerts != null) ...[
                      _CollectorQuickActionsRow(
                        onMap: widget.onOpenMap,
                        onHistory: widget.onOpenHistory,
                        onAlerts: widget.onOpenAlerts,
                      ),
                      const SizedBox(height: _sectionGap),
                    ],
                    _PerformanceStatusSection(
                      wide: wide,
                      cleanlinessFraction: zoneCleanFraction,
                      zoneEmpty: zoneBins.isEmpty,
                      clearsToday: todayImpact.clearsToday,
                      kgToday: todayImpact.kgToday,
                    ),
                    const SizedBox(height: _sectionGap),
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search by bin code or location…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchCtrl.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchCtrl.clear();
                                },
                              ),
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: _sectionGap),
                    if (searchHidesPendingTasks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.amber.shade900),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'You still have bins needing collection in your zone. Clear search to see them.',
                                    style: TextStyle(
                                      color: Colors.amber.shade900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (emptyZone)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            _userZone.isNotEmpty
                                ? 'No bins are linked to zone "$_userZone" yet. '
                                    'Check with your admin or your assignment.'
                                : 'No bins are assigned to you yet.',
                            style: const TextStyle(color: AppColors.subText),
                          ),
                        ),
                      )
                    else if (visible.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'No bins match your search.',
                            style: TextStyle(color: AppColors.subText),
                          ),
                        ),
                      )
                    else ...[
                      if (activeTasks.isNotEmpty) ...[
                        if (activeTasks.any((b) => b.isCritical))
                          const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Tasks for Today',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              label: Text('${activeTasks.length}'),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Colors.orange.shade100,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Critical (≥90%) and warning (70–89%) in your zone',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _TaskGrid(
                          wide: wide,
                          bins: activeTasks,
                          onNavigate: _openMaps,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (allClearInZone && _searchCtrl.text.trim().isEmpty)
                        _SuccessBanner(zoneLabel: _zoneLabel),
                      if (restBins.isNotEmpty) ...[
                        if (allClearInZone &&
                            _searchCtrl.text.trim().isEmpty)
                          const SizedBox(height: 16),
                        Text(
                          'Other bins in your zone',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        _RestBinsList(
                          wide: wide,
                          bins: restBins,
                          onNavigate: _openMaps,
                        ),
                      ],
                    ],
                    const SizedBox(height: _sectionGap),
                    _MyRecentActivity(
                      entries: _myHistory.take(5).toList(),
                    ),
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

/// Zone cleanliness ring + vertical impact stats; wide = ring left / stats right.
class _PerformanceStatusSection extends StatelessWidget {
  final bool wide;
  final double cleanlinessFraction;
  final bool zoneEmpty;
  final int clearsToday;
  final double kgToday;

  const _PerformanceStatusSection({
    required this.wide,
    required this.cleanlinessFraction,
    required this.zoneEmpty,
    required this.clearsToday,
    required this.kgToday,
  });

  String get _kgLabel {
    if (kgToday <= 0) return '0';
    if (kgToday >= 100) return kgToday.toStringAsFixed(0);
    if (kgToday >= 10) return kgToday.toStringAsFixed(1);
    return kgToday.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final impactColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CollectorImpactStatCard(
          title: 'Bins Cleared',
          value: '$clearsToday',
          subtitle: 'Today',
          icon: Icons.check_circle_outline,
          color: AppColors.primaryGreen,
        ),
        const SizedBox(height: 12),
        _CollectorImpactStatCard(
          title: 'Weight Managed',
          value: '$_kgLabel kg',
          subtitle: 'Est. from fill × 0.5',
          icon: Icons.scale_outlined,
          color: Colors.teal.shade700,
        ),
      ],
    );

    final ring = _ZoneCleanlinessRing(
      fraction: cleanlinessFraction,
      zoneEmpty: zoneEmpty,
      compact: !wide,
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Align(
              alignment: Alignment.topCenter,
              child: ring,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 6,
            child: impactColumn,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: ring),
        const SizedBox(height: 16),
        impactColumn,
      ],
    );
  }
}

/// Compact shortcuts to shell tabs; scrolls horizontally when narrow.
class _CollectorQuickActionsRow extends StatelessWidget {
  final VoidCallback? onMap;
  final VoidCallback? onHistory;
  final VoidCallback? onAlerts;

  const _CollectorQuickActionsRow({
    required this.onMap,
    required this.onHistory,
    required this.onAlerts,
  });

  static const double _tileMinWidth = 108;

  @override
  Widget build(BuildContext context) {
    final entries = <({String label, IconData icon, VoidCallback? onTap})>[];
    if (onMap != null) {
      entries.add((
        label: 'View Map',
        icon: Icons.map_outlined,
        onTap: onMap,
      ));
    }
    if (onHistory != null) {
      entries.add((
        label: 'My History',
        icon: Icons.history,
        onTap: onHistory,
      ));
    }
    if (onAlerts != null) {
      entries.add((
        label: 'Notifications',
        icon: Icons.notifications_none,
        onTap: onAlerts,
      ));
    }
    if (entries.isEmpty) return const SizedBox.shrink();

    final green = AppColors.primaryGreen;
    final rowChildren = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      if (i > 0) rowChildren.add(const SizedBox(width: 10));
      final e = entries[i];
      rowChildren.add(
        SizedBox(
          width: _tileMinWidth,
          child: _CollectorQuickActionTile(
            label: e.label,
            icon: e.icon,
            onTap: e.onTap!,
            accent: green,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rowChildren,
      ),
    );
  }
}

class _CollectorQuickActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;

  const _CollectorQuickActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: accent.withValues(alpha: 0.22),
        highlightColor: accent.withValues(alpha: 0.08),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.38)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent, size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mirrors admin [dashboard_screen] `_StatCard` styling.
class _CollectorImpactStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _CollectorImpactStatCard({
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
          ],
        ),
      ),
    );
  }
}

class _ZoneCleanlinessRing extends StatelessWidget {
  final double fraction;
  final bool zoneEmpty;
  final bool compact;

  const _ZoneCleanlinessRing({
    required this.fraction,
    this.zoneEmpty = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    // Taller ring fills vertical space beside the stacked impact cards (esp. on mobile).
    final size = compact ? 176.0 : 168.0;
    final stroke = compact ? 12.0 : 13.0;
    final pctFont = compact ? 26.0 : 25.0;
    final pct = zoneEmpty
        ? 0
        : (fraction * 100).round().clamp(0, 100);
    final value = zoneEmpty ? 0.0 : fraction.clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Zone Cleanliness',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: zoneEmpty ? 0.0 : value,
                  strokeWidth: stroke,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.grey.shade200,
                  color: AppColors.primaryGreen,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      zoneEmpty ? '—' : '$pct%',
                      style: TextStyle(
                        fontSize: pctFont,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (!zoneEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'non-critical',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: compact ? 11 : 10,
                          height: 1.2,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _MyRecentActivity extends StatelessWidget {
  final List<dynamic> entries;

  const _MyRecentActivity({required this.entries});

  static String _timeLabel(dynamic raw) {
    final dt = _CollectorDashboardState._parseCollectionTime(raw);
    if (dt == null) return '—';
    final now = DateTime.now();
    if (_CollectorDashboardState._isSameLocalDay(dt, now)) {
      return DateFormat.jm().format(dt);
    }
    return DateFormat.MMMd().add_jm().format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'My Recent Activity',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Last 5 clears from your history',
          style: TextStyle(color: AppColors.subText, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.cardRadius),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No collections yet.',
                style: TextStyle(color: AppColors.subText),
              ),
            ),
          )
        else
          Card(
            elevation: 2,
            shadowColor: AppColors.cardShadow.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.cardRadius),
            ),
            color: AppColors.cardBackground,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 52,
                color: Colors.grey.shade200,
              ),
              itemBuilder: (context, i) {
                final raw = entries[i];
                final m = raw is Map<String, dynamic>
                    ? raw
                    : Map<String, dynamic>.from(raw as Map);
                final code = m['bin_code']?.toString() ?? '—';
                final when = _timeLabel(m['collection_time']);
                return ListTile(
                  leading: Icon(
                    Icons.check_circle,
                    color: AppColors.primaryGreen,
                    size: 28,
                  ),
                  title: Text(
                    'Bin $code cleared at $when',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  final String zoneLabel;

  const _SuccessBanner({required this.zoneLabel});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.shade400, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green.shade700,
              size: 40,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'All bins in $zoneLabel are under control. Great job!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade900,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskGrid extends StatelessWidget {
  final bool wide;
  final List<BinModel> bins;
  final void Function(BinModel) onNavigate;

  const _TaskGrid({
    required this.wide,
    required this.bins,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = wide ? 2 : 1;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: wide ? 168 : 156,
      ),
      itemCount: bins.length,
      itemBuilder: (context, i) => _TaskCard(
        bin: bins[i],
        onNavigate: () => onNavigate(bins[i]),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final BinModel bin;
  final VoidCallback onNavigate;

  const _TaskCard({
    required this.bin,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final critical = bin.isCritical;
    final bg = critical ? const Color(0xFFB91C1C) : const Color(0xFFC2410C);
    final fg = Colors.white;
    final label = critical ? 'CRITICAL' : 'WARNING';

    return Card(
      elevation: 4,
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${bin.fillLevel.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: fg,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              bin.binCode,
              style: TextStyle(
                color: fg,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                bin.location,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg.withValues(alpha: 0.92),
                  fontSize: 13,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: bg,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: onNavigate,
                icon: const Icon(Icons.navigation, size: 18),
                label: const Text('Navigate'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestBinsList extends StatelessWidget {
  final bool wide;
  final List<BinModel> bins;
  final void Function(BinModel) onNavigate;

  const _RestBinsList({
    required this.wide,
    required this.bins,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    if (wide) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 88,
        ),
        itemCount: bins.length,
        itemBuilder: (context, i) => _RestBinTile(
          bin: bins[i],
          onNavigate: () => onNavigate(bins[i]),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: bins.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _RestBinTile(
        bin: bins[i],
        onNavigate: () => onNavigate(bins[i]),
      ),
    );
  }
}

class _RestBinTile extends StatelessWidget {
  final BinModel bin;
  final VoidCallback onNavigate;

  const _RestBinTile({
    required this.bin,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final hasCoords = bin.latitude != null && bin.longitude != null;
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(
          bin.binCode,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          bin.location,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${bin.fillLevel.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGreen,
              ),
            ),
            IconButton(
              tooltip: 'Navigate',
              icon: const Icon(Icons.navigation_outlined),
              onPressed: hasCoords ? onNavigate : null,
            ),
          ],
        ),
      ),
    );
  }
}
