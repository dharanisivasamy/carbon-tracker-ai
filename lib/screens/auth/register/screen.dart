import 'package:carbon_tracker/core/routes/app_routes.dart';
import 'package:carbon_tracker/core/theme/app_colors.dart';
import 'package:carbon_tracker/core/theme/spacing.dart';
import 'package:carbon_tracker/core/theme/text_styles.dart';
import 'package:carbon_tracker/widgets/buttons/app_button.dart';
import 'package:carbon_tracker/widgets/common/app_text_fields.dart';
import 'package:flutter/material.dart';
import 'package:carbon_tracker/services/api/api_client.dart';
import 'package:carbon_tracker/services/auth/auth_service.dart';
import 'package:carbon_tracker/utils/app_logger.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _hasAcceptedTerms = false;
  final _name=TextEditingController(),_email=TextEditingController(),_password=TextEditingController(),_confirm=TextEditingController(); bool _loading=false;
  Future<void> _register() async { final name=_name.text.trim(),email=_email.text.trim(); String? error; if(name.isEmpty)error='Name is required';else if(!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email))error='Enter a valid email';else if(_password.text.length<8)error='Password must be at least 8 characters';else if(_confirm.text.isEmpty)error='Confirm your password';else if(_password.text!=_confirm.text)error='Passwords do not match'; if(error!=null){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(error)));return;} setState(()=>_loading=true);try{await AuthService.instance.register(name,email,_password.text);if(mounted)Navigator.pushReplacementNamed(context,AppRoutes.dashboard);}catch(e){final message=e is ApiException?e.message:'Registration failed. Please try again.';logDebug('[AUTH] Registration failed: $message');if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));}finally{if(mounted)setState(()=>_loading=false);}}

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
                  Text('Create Account', style: AppTextStyles.headline),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Start making a difference, one trip at a time.',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppTextField(
                    label: 'Full Name',
                    hint: 'Your name',
                    prefixIcon: Icons.person_outline,
                    controller: _name,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: 'Email',
                    hint: 'you@example.com',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    controller: _email,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PasswordField(label: 'Password',controller:_password),
                  const SizedBox(height: AppSpacing.sm),
                  PasswordField(label: 'Confirm Password',controller:_confirm),
                  const SizedBox(height: AppSpacing.xl),
                  _TermsCheckbox(
                    value: _hasAcceptedTerms,
                    onChanged: (value) {
                      setState(() => _hasAcceptedTerms = value ?? false);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LoadingButton(
                    label: 'Create Account',
                    isLoading: _loading,
                    onPressed: _hasAcceptedTerms ? _register : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: AppTextStyles.caption,
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.login,
                        ),
                        child: const Text('Login'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: () => onChanged(!value),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(value: value, onChanged: onChanged),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'I agree to the Terms & Conditions and Privacy Policy.',
              style: AppTextStyles.caption,
            ),
          ),
        ),
      ],
    ),
  );
}
