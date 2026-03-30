import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'collector_sidebar.dart';
import 'notification_bell_with_badge.dart';

/// Breakpoint aligned with collector dashboard / Phase 1 layout split.
const double kCollectorShellBreakpoint = 900;

/// Responsive shell for the collector dashboard: persistent [CollectorSidebar] on
/// wide layouts, drawer + app bar on narrow layouts, and [IndexedStack] so tab
/// state is preserved when switching (no duplicate scaffold in page bodies).
class ResponsiveShell extends StatefulWidget {
  const ResponsiveShell({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.pageTitles,
    required this.pages,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.onLogout,
    required this.unreadNotificationCount,
    required this.onNotificationsOpened,
    this.onRefresh,
  }) : assert(pageTitles.length == pages.length);

  final String userName;
  final String userEmail;
  final List<String> pageTitles;
  final List<Widget> pages;
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onLogout;
  final int unreadNotificationCount;
  final VoidCallback onNotificationsOpened;
  final VoidCallback? onRefresh;

  @override
  State<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends State<ResponsiveShell> {
  bool _sidebarCollapsed = false;

  int get _safeIndex =>
      widget.selectedIndex.clamp(0, widget.pageTitles.length - 1);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= kCollectorShellBreakpoint;

        void selectAndCloseDrawerIfNeeded(int index) {
          widget.onIndexChanged(index);
          if (!wide) {
            final scaffold = Scaffold.maybeOf(context);
            scaffold?.closeDrawer();
          }
        }

        if (wide) {
          return Scaffold(
            backgroundColor: AppColors.scaffoldBackground,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CollectorSidebar(
                  selectedIndex: widget.selectedIndex,
                  collapsed: _sidebarCollapsed,
                  showCollapseButton: true,
                  userName: widget.userName,
                  userEmail: widget.userEmail,
                  onSelect: widget.onIndexChanged,
                  onLogout: widget.onLogout,
                  onToggleCollapsed: () => setState(
                    () => _sidebarCollapsed = !_sidebarCollapsed,
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DesktopTopBar(
                          title: widget.pageTitles[_safeIndex],
                          unreadCount: widget.unreadNotificationCount,
                          onNotificationsOpened: widget.onNotificationsOpened,
                          onRefresh: widget.onRefresh,
                        ),
                        Expanded(
                          child: IndexedStack(
                            index: _safeIndex,
                            sizing: StackFit.expand,
                            children: widget.pages,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          appBar: AppBar(
            title: Text(
              widget.pageTitles[_safeIndex],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: AppColors.scaffoldBackground,
            foregroundColor: AppColors.headerText,
            elevation: 0,
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            actions: [
              NotificationBellWithBadge(
                unreadCount: widget.unreadNotificationCount,
                icon: Icons.notifications,
                iconColor: AppColors.headerText,
                onPressed: () => widget.onNotificationsOpened(),
              ),
              if (widget.onRefresh != null)
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded),
                  color: AppColors.headerText,
                  onPressed: widget.onRefresh,
                ),
            ],
          ),
          drawer: Drawer(
            child: CollectorSidebar(
              selectedIndex: widget.selectedIndex,
              collapsed: false,
              showCollapseButton: false,
              userName: widget.userName,
              userEmail: widget.userEmail,
              onSelect: selectAndCloseDrawerIfNeeded,
              onLogout: () {
                Navigator.of(context).pop();
                widget.onLogout();
              },
            ),
          ),
          body: IndexedStack(
            index: _safeIndex,
            sizing: StackFit.expand,
            children: widget.pages,
          ),
        );
      },
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.title,
    required this.unreadCount,
    required this.onNotificationsOpened,
    this.onRefresh,
  });

  final String title;
  final int unreadCount;
  final VoidCallback onNotificationsOpened;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.scaffoldBackground,
      child: Container(
        height: kToolbarHeight,
        decoration: BoxDecoration(
          color: AppColors.scaffoldBackground,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.headerText,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
              NotificationBellWithBadge(
                unreadCount: unreadCount,
                icon: Icons.notifications,
                iconColor: AppColors.headerText,
                onPressed: () => onNotificationsOpened(),
              ),
            if (onRefresh != null)
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded),
                color: AppColors.headerText,
                onPressed: onRefresh,
              ),
          ],
        ),
      ),
    );
  }
}
