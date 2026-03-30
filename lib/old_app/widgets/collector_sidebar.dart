import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../theme/app_colors.dart';

class CollectorSidebar extends StatelessWidget {
  final int selectedIndex;
  final bool collapsed;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final VoidCallback? onToggleCollapsed;
  final String userName;
  final String userEmail;
  final bool showCollapseButton;

  const CollectorSidebar({
    super.key,
    required this.selectedIndex,
    required this.collapsed,
    required this.onSelect,
    required this.onLogout,
    required this.userName,
    required this.userEmail,
    this.onToggleCollapsed,
    this.showCollapseButton = true,
  });

  @override
  Widget build(BuildContext context) {
    // Fixed desktop sidebar width to keep the dashboard stable on large screens.
    final width = collapsed ? 88.0 : 280.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(3, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildNav()),
            _buildBottom(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final initials = userName.isNotEmpty ? userName[0].toUpperCase() : 'C';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: collapsed ? 18 : 22,
                backgroundColor: AppColors.primaryGreen.withOpacity(0.18),
                child: Text(
                  initials,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                    fontSize: collapsed ? 14 : 16,
                  ),
                ),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SmartWaste',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userEmail.isNotEmpty ? userEmail : 'Collector Panel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (showCollapseButton)
                IconButton(
                  tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    collapsed
                        ? FontAwesomeIcons.chevronRight
                        : FontAwesomeIcons.chevronLeft,
                    size: 16,
                    color: const Color(0xFF94A3B8),
                  ),
                  onPressed: onToggleCollapsed,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNav() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          _Item(
            collapsed: collapsed,
            selected: selectedIndex == 0,
            label: 'Dashboard',
            icon: const Icon(FontAwesomeIcons.house),
            onTap: () => onSelect(0),
          ),
          _Item(
            collapsed: collapsed,
            selected: selectedIndex == 1,
            label: 'Assigned Bins',
            icon: const Icon(FontAwesomeIcons.trashCan),
            onTap: () => onSelect(1),
          ),
          _Item(
            collapsed: collapsed,
            selected: selectedIndex == 2,
            label: 'Route Map',
            icon: const Icon(FontAwesomeIcons.route),
            onTap: () => onSelect(2),
          ),
          _Item(
            collapsed: collapsed,
            selected: selectedIndex == 3,
            label: 'History',
            icon: const Icon(FontAwesomeIcons.clockRotateLeft),
            onTap: () => onSelect(3),
          ),
        ],
      ),
    );
  }

  Widget _buildBottom() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Item(
            collapsed: collapsed,
            selected: selectedIndex == 4,
            label: 'Settings',
            icon: const Icon(FontAwesomeIcons.gear),
            onTap: () => onSelect(4),
          ),
          const SizedBox(height: 6),
          _Item(
            collapsed: collapsed,
            selected: false,
            label: 'Logout',
            icon: const Icon(FontAwesomeIcons.rightFromBracket),
            onTap: onLogout,
            danger: true,
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final bool collapsed;
  final bool selected;
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final bool danger;

  const _Item({
    required this.collapsed,
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.primaryGreen;
    final baseTextColor =
        danger ? const Color(0xFFEF4444) : const Color(0xFFD1D5DB);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: selected
              ? BoxDecoration(
                  color: activeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(width: 3, color: activeColor),
                  ),
                )
              : null,
          child: Row(
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(
                      size: 18,
                      color: selected ? activeColor : baseTextColor,
                    ),
                    child: icon,
                  ),
                ),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? activeColor : baseTextColor,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
