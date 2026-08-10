import 'package:carbon_tracker/core/routes/app_routes.dart';
import 'package:carbon_tracker/core/theme/app_colors.dart';
import 'package:carbon_tracker/core/theme/spacing.dart';
import 'package:carbon_tracker/core/theme/text_styles.dart';
import 'package:carbon_tracker/widgets/buttons/app_button.dart';
import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  static const _items = [
    (
      'Track every trip',
      'Understand your everyday footprint with effortless carbon tracking.',
      Icons.route_rounded,
    ),
    (
      'See smarter forecasts',
      'Explore AI-powered carbon predictions that help you plan ahead.',
      Icons.auto_awesome_rounded,
    ),
    (
      'Make greener choices',
      'Get thoughtful recommendations tailored to your sustainability goals.',
      Icons.eco_rounded,
    ),
  ];
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.login,
                    ),
                    child: const Text('Skip'),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (value) => setState(() => _page = value),
                    itemCount: _items.length,
                    itemBuilder: (_, index) {
                      final item = _items[index];
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 164,
                            height: 164,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: .12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              item.$3,
                              size: 78,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          Text(
                            item.$1,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.headline,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            item.$2,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _items.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(AppSpacing.xxs),
                      height: 8,
                      width: index == _page ? 26 : 8,
                      decoration: BoxDecoration(
                        color: index == _page
                            ? AppColors.primary
                            : AppColors.secondaryText.withValues(alpha: .25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: _page == 2 ? 'Get Started' : 'Next',
                  onPressed: () {
                    if (_page == 2) {
                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
