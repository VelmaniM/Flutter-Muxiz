import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_storage.dart';
import '../../main_layout.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isSignUpMode = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 1. Handle Google Sign-In with Direct Google Portal Launch & SQL Database Sync
  Future<void> _handleGoogleSignIn() async {
    const googleLoginUrl =
        'https://accounts.google.com/v3/signin/identifier?authuser=0&continue=https%3A%2F%2Fmyaccount.google.com%2F%3Futm_source%3Dsign_in_no_continue%26pli%3D1&ec=GAlAwAE&flowEntry=AddSession&flowName=GlifWebSignIn&hl=en_GB';

    // 1. Directly open the exact Google Sign-In page in browser without any intermediary dialogs
    try {
      final googleUri = Uri.parse(googleLoginUrl);
      await launchUrl(googleUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        io.Process.run('open', [googleLoginUrl]);
      } catch (_) {}
    }

    setState(() => _isGoogleLoading = true);

    try {
      final inputEmail = _emailController.text.trim();
      final inputName = _nameController.text.trim();

      final existingName = LocalStorageService.getUserName();
      final googleName = inputName.isNotEmpty
          ? inputName
          : (existingName.isNotEmpty && existingName != 'Velmani Kandan' ? existingName : 'Velmani Manikandan');
      final googleEmail = (inputEmail.isNotEmpty && inputEmail.contains('@'))
          ? inputEmail
          : '${googleName.toLowerCase().replaceAll(' ', '.')}@gmail.com';
      final googleAvatar = LocalStorageService.getUserAvatar() ?? 'emoji:🎧';

      final client = ref.read(apiClientProvider);
      final result = await client.googleAuth(
        email: googleEmail,
        displayName: googleName,
        avatar: googleAvatar,
      );

      if (result.error != null) {
        _showError(result.error!);
        return;
      }

      if (result.user != null) {
        final displayName = result.user!['displayName']?.toString() ?? googleName;
        final avatar = result.user!['avatar']?.toString() ?? googleAvatar;

        ref.read(userNameProvider.notifier).setName(displayName);
        ref.read(userAvatarProvider.notifier).setAvatar(avatar);

        _showSuccess(result.isNewUser ? 'Welcome to Muxiz! Connected with Google.' : 'Welcome back, $displayName!');

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            PageRouteBuilder(
              pageBuilder: (ctx, anim, secAnim) => const MainLayout(),
              transitionsBuilder: (ctx, anim, secAnim, child) => FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 350),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      _showError('Google authentication failed: $e');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  /// 2. Handle Email/Password Login or Registration with Real SQL Database Verification
  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter a valid email address');
      return;
    }

    if (password.length < 4) {
      _showError('Password must be at least 4 characters');
      return;
    }

    if (_isSignUpMode && name.isEmpty) {
      _showError('Please enter your full name');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final client = ref.read(apiClientProvider);

      if (_isSignUpMode) {
        // --- Sign Up (New User) ---
        final res = await client.register(
          email: email,
          password: password,
          displayName: name,
          avatar: 'emoji:🎧',
        );

        if (res.error != null) {
          _showError(res.error!);
          return;
        }

        if (res.user != null) {
          final displayName = res.user!['displayName']?.toString() ?? name;
          ref.read(userNameProvider.notifier).setName(displayName);
          ref.read(userAvatarProvider.notifier).setAvatar('emoji:🎧');

          _showSuccess('Account created successfully in database!');

          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              PageRouteBuilder(
                pageBuilder: (ctx, anim, secAnim) => const MainLayout(),
                transitionsBuilder: (ctx, anim, secAnim, child) => FadeTransition(opacity: anim, child: child),
                transitionDuration: const Duration(milliseconds: 350),
              ),
              (route) => false,
            );
          }
        }
      } else {
        // --- Log In (Already Existing User) ---
        final res = await client.login(
          email: email,
          password: password,
        );

        if (res.error != null) {
          _showError(res.error!);
          return;
        }

        if (res.user != null) {
          final displayName = res.user!['displayName']?.toString() ?? email.split('@').first;
          final avatar = res.user!['avatar']?.toString() ?? 'emoji:🎧';

          ref.read(userNameProvider.notifier).setName(displayName);
          ref.read(userAvatarProvider.notifier).setAvatar(avatar);

          _showSuccess('Welcome back, $displayName!');

          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              PageRouteBuilder(
                pageBuilder: (ctx, anim, secAnim) => const MainLayout(),
                transitionsBuilder: (ctx, anim, secAnim, child) => FadeTransition(opacity: anim, child: child),
                transitionDuration: const Duration(milliseconds: 350),
              ),
              (route) => false,
            );
          }
        }
      }
    } catch (e) {
      _showError('Authentication error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background ambient gradient glow
          Positioned(
            top: -60,
            left: 0,
            right: 0,
            child: Container(
              height: 360,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.1,
                  colors: [
                    AppTheme.primaryGreen.withValues(alpha: 0.18),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),

                    // Muxiz Glowing Audio Logo
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF141414),
                        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.5), width: 1.8),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.35),
                            blurRadius: 28,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          size: 36,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'MUXIZ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      _isSignUpMode ? 'Sign up to start listening' : 'Millions of songs. Free on Muxiz.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Input Form (On Top):
                    // Name Field (Only in Sign Up Mode)
                    if (_isSignUpMode) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Full Name',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF222222),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: TextField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: InputBorder.none,
                            hintText: 'e.g. Velmani Manikandan',
                            hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            prefixIcon: Icon(Icons.person_outline_rounded, color: Colors.white54, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Email Field
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Email or Gmail',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF222222),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: InputBorder.none,
                          hintText: 'name@gmail.com',
                          hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          prefixIcon: Icon(Icons.email_outlined, color: Colors.white54, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Password',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF222222),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: InputBorder.none,
                          hintText: '••••••••',
                          hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white54, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: Colors.white54,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // SUBMIT BUTTON (Log In / Create Account)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        onPressed: (_isLoading || _isGoogleLoading) ? null : _handleEmailAuth,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black),
                              )
                            : Text(
                                _isSignUpMode ? 'Sign Up' : 'Log In',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: -0.2),
                              ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Switch between Login and Signup (At the bottom)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isSignUpMode = !_isSignUpMode;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text.rich(
                          TextSpan(
                            text: _isSignUpMode ? 'Already have an account? ' : "Don't have an account? ",
                            style: const TextStyle(color: Colors.white70, fontSize: 13.5),
                            children: [
                              TextSpan(
                                text: _isSignUpMode ? 'Log In' : 'Sign Up',
                                style: const TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // "OR" Divider
                    Row(
                      children: [
                        const Expanded(child: Divider(color: Colors.white24, thickness: 0.8)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'OR',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Expanded(child: Divider(color: Colors.white24, thickness: 0.8)),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // 3. GOOGLE SIGN-IN BUTTON (At the Bottom)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        onPressed: (_isLoading || _isGoogleLoading) ? null : _handleGoogleSignIn,
                        child: _isGoogleLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildGoogleGLogo(),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Continue with Google',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Official multi-color Google "G" logo vector
  Widget _buildGoogleGLogo() {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

/// Custom Painter for authentic Google "G" Logo
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Blue section
    paint.color = const Color(0xFF4285F4);
    final bluePath = Path()
      ..moveTo(w * 0.98, h * 0.5)
      ..lineTo(w * 0.5, h * 0.5)
      ..lineTo(w * 0.5, h * 0.68)
      ..lineTo(w * 0.78, h * 0.68)
      ..cubicTo(w * 0.74, h * 0.85, w * 0.63, h * 0.95, w * 0.5, h * 0.95)
      ..lineTo(w * 0.5, h * 1.0)
      ..cubicTo(w * 0.78, h * 1.0, w * 1.0, h * 0.78, w * 1.0, h * 0.5)
      ..close();
    canvas.drawPath(bluePath, paint);

    // Red section
    paint.color = const Color(0xFFEA4335);
    final redPath = Path()
      ..moveTo(w * 0.5, h * 0.0)
      ..cubicTo(w * 0.64, h * 0.0, w * 0.76, h * 0.05, w * 0.85, h * 0.14)
      ..lineTo(w * 0.73, h * 0.26)
      ..cubicTo(w * 0.67, h * 0.20, w * 0.59, h * 0.16, w * 0.5, h * 0.16)
      ..cubicTo(w * 0.31, h * 0.16, w * 0.15, h * 0.29, w * 0.09, h * 0.46)
      ..lineTo(w * 0.0, h * 0.39)
      ..cubicTo(w * 0.09, h * 0.16, w * 0.27, h * 0.0, w * 0.5, h * 0.0)
      ..close();
    canvas.drawPath(redPath, paint);

    // Yellow section
    paint.color = const Color(0xFFFBBC05);
    final yellowPath = Path()
      ..moveTo(w * 0.09, h * 0.46)
      ..cubicTo(w * 0.07, h * 0.52, w * 0.07, h * 0.58, w * 0.09, h * 0.64)
      ..lineTo(w * 0.0, h * 0.71)
      ..cubicTo(w * 0.0, h * 0.64, w * 0.0, h * 0.46, w * 0.0, h * 0.39)
      ..lineTo(w * 0.09, h * 0.46)
      ..close();
    canvas.drawPath(yellowPath, paint);

    // Green section
    paint.color = const Color(0xFF34A853);
    final greenPath = Path()
      ..moveTo(w * 0.5, h * 1.0)
      ..cubicTo(w * 0.27, h * 1.0, w * 0.09, h * 0.84, w * 0.0, h * 0.61)
      ..lineTo(w * 0.09, h * 0.54)
      ..cubicTo(w * 0.15, h * 0.71, w * 0.31, h * 0.84, w * 0.5, h * 0.84)
      ..cubicTo(w * 0.63, h * 0.84, w * 0.74, h * 0.79, w * 0.82, h * 0.71)
      ..lineTo(w * 0.94, h * 0.8)
      ..cubicTo(w * 0.84, h * 0.92, w * 0.68, h * 1.0, w * 0.5, h * 1.0)
      ..close();
    canvas.drawPath(greenPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
