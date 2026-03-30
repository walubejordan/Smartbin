import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

/// Collector collection history from [ApiService.getCollectionHistory].
class CollectorHistoryScreen extends StatefulWidget {
  const CollectorHistoryScreen({super.key});

  @override
  State<CollectorHistoryScreen> createState() => _CollectorHistoryScreenState();
}

class _CollectorHistoryScreenState extends State<CollectorHistoryScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<dynamic>> _fetch() async {
    final api = Provider.of<ApiService>(context, listen: false);
    return api.getCollectionHistory();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _fetch();
    });
    await _future;
  }

  static String _formatTime(dynamic raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return raw.toString();
    return DateFormat.yMMMd().add_jm().format(dt.toLocal());
  }

  static double _fillBefore(Map<String, dynamic> m) {
    final v = m['fill_level_before'];
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('${snapshot.error}'),
                  ),
                ),
              ],
            );
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(32),
              children: const [
                Center(
                  child: Text(
                    'No collections yet.',
                    style: TextStyle(color: AppColors.subText),
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final raw = list[i];
              final m = raw is Map<String, dynamic>
                  ? raw
                  : Map<String, dynamic>.from(raw as Map);
              final code = m['bin_code']?.toString() ?? '—';
              final loc =
                  m['location_name']?.toString() ?? m['location']?.toString() ?? '—';
              final when = _formatTime(m['collection_time']);
              final cleared = _fillBefore(m);
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
                            child: Text(
                              code,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primaryGreen.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              'Cleared ${cleared.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loc,
                        style: const TextStyle(
                          color: AppColors.subText,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: AppColors.subText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            when,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
