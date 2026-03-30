import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bin_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class BinsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final void Function(double lat, double lng)? onShowBinOnMap;
  /// When true (collectors), show [Confirm Collection] for assigned bins with fill &gt; 0.
  final bool enableCollection;
  /// Called after a successful collect (e.g. refresh map).
  final VoidCallback? onCollectionComplete;

  const BinsScreen({
    super.key,
    required this.user,
    this.onShowBinOnMap,
    this.enableCollection = false,
    this.onCollectionComplete,
  });

  @override
  State<BinsScreen> createState() => BinsScreenState();
}

class BinsScreenState extends State<BinsScreen> {
  List<BinModel> _bins = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  int? _collectingBinId;

  int? get _userId {
    final v = widget.user['id'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Reload bins from the API (e.g. after map collect).
  Future<void> reload() => _load();

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
        _bins = BinModel.listFromDynamic(raw);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<BinModel> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _bins;
    return _bins.where((b) {
      return b.binCode.toLowerCase().contains(q) ||
          b.location.toLowerCase().contains(q) ||
          (b.name ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Color _statusColor(BinModel b) {
    if (b.isCritical) return Colors.red.shade700;
    if (b.isWarning) return Colors.orange.shade800;
    return AppColors.primaryGreen;
  }

  bool _canCollect(BinModel b) {
    if (!widget.enableCollection) return false;
    final uid = _userId;
    if (uid == null || b.assignedTo != uid) return false;
    return b.fillLevel > 0;
  }

  Future<void> _confirmCollect(BinModel b) async {
    final api = Provider.of<ApiService>(context, listen: false);
    setState(() => _collectingBinId = b.id);
    try {
      await api.collectBin(b.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bin Emptied Successfully'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onCollectionComplete?.call();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _collectingBinId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
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
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by code, name, or location',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!),
                      ),
                    ),
                  if (_loading)
                    const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No bins match your search.',
                          style: TextStyle(color: AppColors.subText),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final b = _filtered[i];
                        final fill = b.fillLevel / 100.0;
                        final statusColor = _statusColor(b);
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            Text(
                                              b.binCode,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: statusColor
                                                    .withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                b.status,
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    _BatteryBadge(percent: b.batteryPercent),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  b.location,
                                  style: const TextStyle(
                                    color: AppColors.subText,
                                    fontSize: 13,
                                  ),
                                ),
                                if (b.collectorName != null &&
                                    b.collectorName!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Collector: ${b.collectorName}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: fill.clamp(0.0, 1.0),
                                          minHeight: 10,
                                          backgroundColor:
                                              Colors.grey.shade200,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            statusColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '${b.fillLevel.toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (widget.onShowBinOnMap != null &&
                                        b.latitude != null &&
                                        b.longitude != null) ...[
                                      const SizedBox(width: 8),
                                      IconButton.filledTonal(
                                        tooltip: 'Show on map',
                                        onPressed: () => widget.onShowBinOnMap!(
                                          b.latitude!,
                                          b.longitude!,
                                        ),
                                        icon: const Icon(Icons.map_outlined),
                                      ),
                                    ],
                                  ],
                                ),
                                if (_canCollect(b)) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: _collectingBinId != null
                                          ? null
                                          : () => _confirmCollect(b),
                                      icon: _collectingBinId == b.id
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.check_circle_outline),
                                      label: Text(
                                        _collectingBinId == b.id
                                            ? 'Processing...'
                                            : 'Confirm Collection',
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BatteryBadge extends StatelessWidget {
  final int? percent;

  const _BatteryBadge({this.percent});

  @override
  Widget build(BuildContext context) {
    final p = percent;
    IconData icon;
    Color color;
    if (p == null) {
      icon = Icons.battery_unknown;
      color = AppColors.subText;
    } else if (p <= 15) {
      icon = Icons.battery_alert;
      color = Colors.red.shade700;
    } else if (p <= 35) {
      icon = Icons.battery_3_bar;
      color = Colors.orange.shade800;
    } else {
      icon = Icons.battery_full;
      color = AppColors.primaryGreen;
    }

    return Tooltip(
      message: p == null ? 'Battery data unavailable' : 'Battery $p%',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          if (p != null) ...[
            const SizedBox(width: 4),
            Text(
              '$p%',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
