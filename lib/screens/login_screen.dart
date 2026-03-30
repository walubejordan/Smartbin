import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/mqtt_service.dart';
import '../services/push_notifications_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_shell.dart';

/// Login hero: smart waste / IoT bins artwork (`assets/reference/`).
const String _kLoginHeroAsset = 'assets/reference/login_smart_waste_hero.png';

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

      final user = response['data']['user'] as Map<String, dynamic>;

      await mqttService.connect(user['id'].toString());

      try {
        final fcmToken = await pushService.getToken();
        if (fcmToken != null && fcmToken.isNotEmpty) {
          await apiService.updateFcmToken(fcmToken);
        }
      } catch (e) {
        debugPrint('Failed to sync FCM token after login: $e');
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => AppShell(user: user)),
      );
    } catch (e) {
      if (!mounted) return;

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
    const outerPad = 24.0;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > AppShell.breakpoint;
            final screenH = MediaQuery.sizeOf(context).height;
            final minScrollContentHeight = constraints.hasBoundedHeight
                ? (constraints.maxHeight - 2 * outerPad)
                    .clamp(0.0, double.infinity)
                : (screenH - 2 * outerPad).clamp(0.0, double.infinity);

            final wideContent = Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.all(outerPad),
                  child: SizedBox(
                    height: (constraints.maxHeight - 2 * outerPad)
                        .clamp(320.0, double.infinity),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildHeroCard(stretch: true)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildLoginCard(stretch: true)),
                      ],
                    ),
                  ),
                ),
              ),
            );

            final narrowContent = Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(outerPad),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: minScrollContentHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeroCard(fixedHeight: 220),
                        const SizedBox(height: 24),
                        _buildLoginCard(stretch: false),
                      ],
                    ),
                  ),
                ),
              ),
            );

            return isWide ? wideContent : narrowContent;
          },
        ),
      ),
    );
  }

  /// Hero card. Use [fixedHeight] on mobile (scroll layout). Use [stretch: true]
  /// inside a [Row] with [CrossAxisAlignment.stretch] and a finite [SizedBox] height.
  Widget _buildHeroCard({double? fixedHeight, bool stretch = false}) {
    assert(fixedHeight != null || stretch);
    assert(fixedHeight == null || !stretch);

    final card = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            spreadRadius: 2,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Image.asset(
              _kLoginHeroAsset,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Missing asset: $_kLoginHeroAsset',
                      style: TextStyle(color: AppColors.subText),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );

    if (fixedHeight != null) {
      return SizedBox(height: fixedHeight, width: double.infinity, child: card);
    }
    return card;
  }

  List<Widget> _loginFormFields() {
    return [
        const CircleAvatar(
          radius: 30,
          backgroundColor: AppColors.primaryGreen,
          child: Icon(Icons.recycling, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 18),
        const Text(
          'SmartBin',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: AppColors.headerText,
          ),
        ),
        const SizedBox(height: 6),
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
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
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
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
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
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
    ];
  }

  Widget _buildLoginFormColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: _loginFormFields(),
    );
  }

  /// Login card: full-height on desktop ([stretch]: scroll + centered form).
  Widget _buildLoginCard({required bool stretch}) {
    final decoration = BoxDecoration(
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
    );

    if (!stretch) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: decoration,
        child: Form(
          key: _formKey,
          child: _buildLoginFormColumn(),
        ),
      );
    }

    return Container(
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) {
          return SizedBox(
            height: c.maxHeight,
            width: double.infinity,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: Form(
                      key: _formKey,
                      child: _buildLoginFormColumn(),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
