import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Local notifications + in-app fallback when the app is foregrounded.
class NotificationService {
  NotificationService._();

  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static const String _androidChannelId = 'smartbin_fill_alerts';
  static const String _androidChannelName = 'Fill level alerts';
  static const String _androidChannelDesc =
      'Alerts when a bin fill level reaches your admin threshold';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  static AppLifecycleState get lifecycle => _instance._lifecycle;

  void updateLifecycle(AppLifecycleState state) {
    _lifecycle = state;
  }

  /// Initialize Android + iOS notification surfaces.
  Future<void> initialize() async {
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      ),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _androidChannelId,
          _androidChannelName,
          description: _androidChannelDesc,
          importance: Importance.high,
        ),
      );
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    final mac = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    await mac?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  /// Shows a system notification and, when the app is in the foreground, a SnackBar.
  static Future<void> showNotification(String binCode, String location) {
    return _instance._show(binCode, location);
  }

  Future<void> _show(String binCode, String location) async {
    final title = 'Bin $binCode — high fill level';
    final body = location.isEmpty
        ? 'Fill level reached your alert threshold.'
        : '$location — fill level reached your alert threshold.';

    if (!kIsWeb && _initialized) {
      try {
        await _plugin.show(
          binCode.hashCode & 0x7fffffff,
          title,
          body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannelId,
              _androidChannelName,
              channelDescription: _androidChannelDesc,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
            macOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        );
      } catch (e, st) {
        debugPrint('Local notification failed: $e\n$st');
      }
    }

    _showFallbackUi(title, body);
  }

  void _showFallbackUi(String title, String body) {
    if (_lifecycle != AppLifecycleState.resumed) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = scaffoldMessengerKey.currentState;
      if (messenger == null) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(body),
            ],
          ),
          action: SnackBarAction(
            label: 'Dismiss',
            onPressed: () =>
                scaffoldMessengerKey.currentState?.hideCurrentSnackBar(),
          ),
        ),
      );
    });
  }
}
