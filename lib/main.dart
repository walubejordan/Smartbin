import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'widgets/app_shell.dart';
import 'services/api_service.dart';
import 'services/mqtt_service.dart';
import 'services/notification_service.dart';
import 'services/push_notifications_service.dart';
import 'firebase_options.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme_mode.dart';

void main() async {
  // Ensure Flutter is initialized before calling asynchronous services
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (required for FCM).
  // NOTE: Replace placeholder options in `firebase_options.dart` (or generate with FlutterFire).
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // If Firebase isn't configured yet, we still allow the app to run.
    debugPrint('Firebase init skipped/failed: $e');
  }

  // Initialize API service
  final apiService = ApiService();
  try {
    await apiService.init();
  } catch (e) {
    debugPrint('API service initialization error: $e');
  }

  // Initialize push notifications (FCM)
  final pushService = PushNotificationsService();
  try {
    await pushService.init();
    // After permissions and FirebaseMessaging init, fetch FCM token and sync to backend
    if (apiService.hasToken) {
      final token = await pushService.getToken();
      if (token != null && token.isNotEmpty) {
        try {
          await apiService.updateFcmToken(token);
        } catch (e) {
          debugPrint('Failed to update FCM token: $e');
        }
      }
    }
  } catch (e) {
    debugPrint('Push notifications init failed: $e');
  }

  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Local notifications init failed: $e');
  }

  final appThemeMode = AppThemeMode();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppThemeMode>.value(value: appThemeMode),
        Provider<ApiService>.value(value: apiService),
        Provider<MqttService>(create: (_) => MqttService()),
        Provider<PushNotificationsService>.value(value: pushService),
      ],
      child: const SmartBinApp(),
    ),
  );
}

class SmartBinApp extends StatefulWidget {
  const SmartBinApp({super.key});

  @override
  State<SmartBinApp> createState() => _SmartBinAppState();
}

class _SmartBinAppState extends State<SmartBinApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    NotificationService.instance.updateLifecycle(state);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppThemeMode>(
      builder: (context, appTheme, _) {
        return MaterialApp(
          navigatorKey: NotificationService.navigatorKey,
          scaffoldMessengerKey: NotificationService.scaffoldMessengerKey,
          title: 'SmartBin',
          debugShowCheckedModeBanner: false,
          themeMode: appTheme.mode,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          routes: {
            '/login': (_) => const LoginScreen(),
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}

ThemeData _buildLightTheme() {
  final baseTextTheme = GoogleFonts.interTextTheme(
    ThemeData(useMaterial3: true).textTheme,
  );

  final themedTextTheme = baseTextTheme.copyWith(
    titleLarge: baseTextTheme.titleLarge?.copyWith(
      color: AppColors.headerText,
      fontWeight: FontWeight.w700,
    ),
    headlineSmall: baseTextTheme.headlineSmall?.copyWith(
      color: AppColors.headerText,
      fontWeight: FontWeight.w700,
    ),
    titleMedium: baseTextTheme.titleMedium?.copyWith(
      color: AppColors.headerText,
      fontWeight: FontWeight.w600,
    ),
    bodySmall: baseTextTheme.bodySmall?.copyWith(
      color: AppColors.subText,
    ),
    bodyMedium: baseTextTheme.bodyMedium?.copyWith(
      color: AppColors.headerText,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.scaffoldBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryGreen,
      primary: AppColors.primaryGreen,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: AppColors.scaffoldBackground,
      foregroundColor: AppColors.headerText,
    ),
    textTheme: themedTextTheme,
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: AppColors.primaryGreen),
      ),
    ),
  );
}

ThemeData _buildDarkTheme() {
  const scaffoldDark = Color(0xFF0F172A);
  const cardDark = Color(0xFF1E293B);

  final darkBase = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryGreen,
      brightness: Brightness.dark,
      primary: AppColors.primaryGreen,
    ),
  );

  final baseTextTheme = GoogleFonts.interTextTheme(darkBase.textTheme);

  return darkBase.copyWith(
    scaffoldBackgroundColor: scaffoldDark,
    textTheme: baseTextTheme,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: scaffoldDark,
      foregroundColor: Colors.white,
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      color: cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: AppColors.primaryGreen),
      ),
    ),
  );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Delay auth check until after first frame to avoid Provider access issues in initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  Future<void> _checkAuth() async {
    try {
      if (!mounted) return;

      final apiService = Provider.of<ApiService>(context, listen: false);

      // Splash screen delay
      await Future.delayed(const Duration(seconds: 2));

      // Check if token exists
      if (!mounted) return;

      if (!apiService.hasToken) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      try {
        final profile = await apiService.getProfile();

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => AppShell(user: profile)),
        );
      } catch (e) {
        debugPrint('Error getting profile: $e');
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      debugPrint('Auth check error: $e');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.delete_outline,
                size: 60,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'SmartBin',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppColors.headerText,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Intelligent Waste Management',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.subText,
              ),
            ),
            const SizedBox(height: 50),
            const CircularProgressIndicator(
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}
