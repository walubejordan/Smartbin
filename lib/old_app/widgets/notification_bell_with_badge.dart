import 'package:flutter/material.dart';

import 'pulsing_badge.dart';

class NotificationBellWithBadge extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onPressed;
  final IconData icon;
  final Color iconColor;

  const NotificationBellWithBadge({
    super.key,
    required this.unreadCount,
    required this.onPressed,
    this.icon = Icons.notifications_outlined,
    this.iconColor = Colors.black54,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(icon, color: iconColor),
          onPressed: onPressed,
        ),
        PulsingBadge(
          visible: hasUnread,
          color: Colors.red,
          size: 10,
          topPadding: 10,
          rightPadding: 10,
        ),
      ],
    );
  }
}

