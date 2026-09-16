import 'package:flutter/material.dart';

import 'package:carbon_tracker/core/routes/app_routes.dart';
import 'package:carbon_tracker/core/theme/app_colors.dart';
import 'package:carbon_tracker/core/theme/spacing.dart';
import 'package:carbon_tracker/core/theme/text_styles.dart';
import 'package:carbon_tracker/services/api/api_client.dart';
import 'package:carbon_tracker/services/auth/auth_service.dart';
import 'package:carbon_tracker/utils/app_logger.dart';
import 'package:carbon_tracker/widgets/buttons/app_button.dart';
import 'package:carbon_tracker/widgets/common/app_text_fields.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _googleLoading = false;
  bool _shownRouteMessage = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Shows a message passed via route arguments exactly once (e.g. "Session
    // expired. Please log in again." after a 401 on a protected request).
    if (_shownRouteMessage) return;
    final message = ModalRoute.of(context)?.settings.arguments;
    if (message is String && message.isNotEmpty) {
      _shownRouteMessage = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading || _googleLoading) return;

    if (_email.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Email is required.')));
      return;
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(_email.text.trim())) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid email.')));
      return;
    }
    if (_password.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password is required.')));
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await AuthService.instance.login(_email.text.trim(), _password.text);

      if (!mounted) return;

      Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
    } catch (e) {
      final message = e is ApiException
          ? e.message
          : 'Something went wrong. Please try again.';
      logDebug('[AUTH] Login failed: $message');
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_loading || _googleLoading) return;

    setState(() => _googleLoading = true);
    try {
      await AuthService.instance.signInWithGoogle();
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Signed in with Google.')));
      Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
    } on ApiException catch (error) {
      logDebug('[AUTH] Google backend sign-in failed: ${error.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on GoogleAuthenticationException catch (error) {
      logDebug('[AUTH] Google Sign-In failed: ${error.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Sign-In failed. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthShell(
      title: 'Welcome Back',
      subtitle: 'Sign in to continue your climate journey',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Email address',
            hint: 'you@example.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            controller: _email,
          ),

          const SizedBox(height: AppSpacing.sm),

          PasswordField(label: 'Password', controller: _password),

          LoadingButton(label: 'Login', isLoading: _loading, onPressed: _login),

          const SizedBox(height: AppSpacing.md),

          const _Divider(),

          const SizedBox(height: AppSpacing.md),

          AppOutlinedButton(
            label: _googleLoading
                ? 'Signing in with Google...'
                : 'Continue with Google',
            leading: const _GoogleMark(),
            onPressed: _loading || _googleLoading ? null : _signInWithGoogle,
          ),

          const SizedBox(height: AppSpacing.xl),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Don't have an account?", style: AppTextStyles.caption),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.register);
                },
                child: const Text('Sign Up'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuthShell extends StatelessWidget {
  const _AuthShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.eco_rounded,
                    color: AppColors.primary,
                    size: 42,
                  ),

                  const SizedBox(height: AppSpacing.xxxl),

                  Text(title, style: AppTextStyles.headline),

                  const SizedBox(height: AppSpacing.xs),

                  Text(subtitle, style: AppTextStyles.body),

                  const SizedBox(height: AppSpacing.xxl),

                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text('OR', style: AppTextStyles.caption),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
