import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/mqtt_service.dart';
import '../../services/push_notifications_service.dart';
import 'admin/admin_dashboard.dart';
import 'collector/collector_dashboard.dart';
import '../../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final apiService = Provider.of<ApiService>(context, listen: false);
    final mqttService = Provider.of<MqttService>(context, listen: false);
    final pushService =
        Provider.of<PushNotificationsService>(context, listen: false);

    try {
      final response = await apiService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      final user = response['data']['user'];

      // Connect to MQTT for real-time notifications
      await mqttService.connect(user['id'].toString());

      // After successful login, obtain FCM token and sync to backend
      try {
        final fcmToken = await pushService.getToken();
        if (fcmToken != null && fcmToken.isNotEmpty) {
          await apiService.updateFcmToken(fcmToken);
        }
      } catch (e) {
        // Non-fatal: logging is enough, login should still proceed
        debugPrint('Failed to sync FCM token after login: $e');
      }

      if (!mounted) return;

      // Navigate based on role
      if (user['role'] == 'admin') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => AdminDashboard(user: user)),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => CollectorDashboard(user: user)),
        );
      }
    } catch (e) {
      if (!mounted) return;

      // Show a friendly message when the backend is still waking up on Render
      // or when there are generic network/cold-start issues.
      var message = e.toString().replaceAll('Exception: ', '');
      final lower = message.toLowerCase();
      if (lower.contains(
              'server is waking up, please try again in 30 seconds.') ||
          lower.contains('server error during login') ||
          lower.contains('xmlhttprequest error') ||
          lower.contains('timed out') ||
          lower.contains('failed host lookup')) {
        message = 'Server is waking up, please try again in 30 seconds.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 900;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: isWide
                  ? Row(
                      children: [
                        Expanded(child: _buildHeroPanel()),
                        const SizedBox(width: 24),
                        Expanded(child: _buildLoginPanel()),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildHeroPanel(compact: true),
                          const SizedBox(height: 24),
                          _buildLoginPanel(),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroPanel({bool compact = false}) {
    return Container(
      height: compact ? 240 : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.cardBackground,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            spreadRadius: 2,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/reference/truck-hero.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Text(
                    'Missing asset: assets/reference/truck-hero.png',
                    style: TextStyle(color: AppColors.subText),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'SMARTBIN OPERATIONS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPanel() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            spreadRadius: 2,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primaryGreen,
              child: Icon(Icons.recycling, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 18),
            const Text(
              'Welcome Back',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: AppColors.headerText,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sign in to manage SmartBin collection operations',
              style: TextStyle(color: AppColors.subText),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Your email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Please enter your email';
                if (!value.contains('@')) return 'Please enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Your password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Please enter your password';
                if (value.length < 6)
                  return 'Password must be at least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: AppColors.signInButton,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Sign In',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
