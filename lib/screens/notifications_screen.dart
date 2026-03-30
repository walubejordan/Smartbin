import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  int _unreadCount = 0;
  bool _loading = true;
  bool _unreadOnly = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final data = await api.getNotifications(
        isRead: _unreadOnly ? false : null,
      );
      if (!mounted) return;
      setState(() {
        _notifications = List<dynamic>.from(data['data'] ?? []);
        _unreadCount = data['unread_count'] is int
            ? data['unread_count'] as int
            : int.tryParse('${data['unread_count']}') ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _markRead(int id) async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.markNotificationRead(id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  void _openDetail(Map<String, dynamic> n) {
    final type = n['type'] ?? 'info';
    Color typeColor;
    switch (type) {
      case 'critical':
        typeColor = Colors.red;
        break;
      case 'warning':
        typeColor = Colors.orange;
        break;
      case 'success':
        typeColor = Colors.green;
        break;
      default:
        typeColor = Colors.blue;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            type.toString().toUpperCase(),
                            style: TextStyle(
                              color: typeColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDate(n['created_at']?.toString()),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.subText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      n['title']?.toString() ?? 'Notification',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      n['message']?.toString() ?? '',
                      style: const TextStyle(height: 1.45),
                    ),
                    if (n['bin_code'] != null ||
                        n['bin_location'] != null) ...[
                      const SizedBox(height: 16),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bin',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              if (n['bin_code'] != null)
                                Text('Code: ${n['bin_code']}'),
                              if (n['bin_location'] != null)
                                Text('Location: ${n['bin_location']}'),
                              if (n['bin_status'] != null)
                                Text('Status: ${n['bin_status']}'),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_unreadCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text('$_unreadCount unread'),
                        ),
                      ),
                    FilterChip(
                      label: const Text('Unread only'),
                      selected: _unreadOnly,
                      onSelected: (v) {
                        setState(() => _unreadOnly = v);
                        _load();
                      },
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _notifications.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_off_outlined,
                                    size: 56, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  _unreadOnly
                                      ? 'No unread notifications'
                                      : 'No notifications yet',
                                  style: const TextStyle(
                                      color: AppColors.subText),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _notifications.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final n = _notifications[i]
                                  as Map<String, dynamic>;
                              final isRead = n['is_read'] == 1 ||
                                  n['is_read'] == true;
                              final type = n['type'] ?? 'info';
                              Color iconColor;
                              IconData icon;
                              switch (type) {
                                case 'critical':
                                  iconColor = Colors.red;
                                  icon = Icons.warning_amber;
                                  break;
                                case 'warning':
                                  iconColor = Colors.orange;
                                  icon = Icons.info_outline;
                                  break;
                                case 'success':
                                  iconColor = Colors.green;
                                  icon = Icons.check_circle_outline;
                                  break;
                                default:
                                  iconColor = Colors.blue;
                                  icon = Icons.notifications_outlined;
                              }
                              return Card(
                                color: isRead
                                    ? null
                                    : Colors.blue.shade50.withOpacity(0.35),
                                child: InkWell(
                                  onTap: () {
                                    final rawId = n['id'];
                                    final nid = rawId is int
                                        ? rawId
                                        : int.tryParse('$rawId');
                                    if (!isRead && nid != null) {
                                      _markRead(nid);
                                    }
                                    _openDetail(n);
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          backgroundColor:
                                              iconColor.withOpacity(0.12),
                                          child: Icon(icon, color: iconColor),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  n['title']?.toString() ?? '',
                                                  style: TextStyle(
                                                    fontWeight: isRead
                                                        ? FontWeight.w500
                                                        : FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  n['message']?.toString() ??
                                                      '',
                                                  maxLines: 3,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  _formatDate(
                                                    n['created_at']?.toString(),
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.subText,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (!isRead)
                                          const Icon(Icons.circle,
                                              size: 10, color: Colors.blue),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }
}
