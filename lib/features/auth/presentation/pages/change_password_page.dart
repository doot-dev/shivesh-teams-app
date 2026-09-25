import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_animations.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../providers/auth_providers.dart';

/// Change the signed-in technician's password.
///
/// The old password is always required — the server re-checks it, so this form
/// is convenience, not the security boundary. Input styling is inherited from
/// the global theme; an earlier version hand-rolled its own InputDecoration and
/// drifted out of sync with the rest of the app.
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;

  @override
  void initState() {
    super.initState();
    // Drives the live strength meter.
    _newController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();

    final ok = await ref
        .read(authProvider.notifier)
        .changePassword(_oldController.text, _newController.text);

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(child: Text('Password changed successfully.')),
            ],
          ),
          backgroundColor: AppColors.success,
          margin: const EdgeInsets.all(AppSpacing.lg),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.danger,
            margin: const EdgeInsets.all(AppSpacing.lg),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const BackButton(color: AppColors.textPrimary),
        title: const Text('Change Password'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.xxxl,
          ),
          children: [
            FadeSlideIn(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.blue100),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.key_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Choose a password you have not used before. '
                        'You will stay signed in on this device.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.blue800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FieldLabel('CURRENT PASSWORD', required: true),
                  TextFormField(
                    controller: _oldController,
                    obscureText: _obscureOld,
                    enabled: !authState.isLoading,
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Enter your current password'
                        : null,
                    decoration: InputDecoration(
                      hintText: 'Enter current password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: _EyeButton(
                        obscured: _obscureOld,
                        onPressed: () =>
                            setState(() => _obscureOld = !_obscureOld),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FieldLabel('NEW PASSWORD', required: true),
                  TextFormField(
                    controller: _newController,
                    obscureText: _obscureNew,
                    enabled: !authState.isLoading,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter a new password';
                      // Mirrors the server rule so the user isn't bounced by a 422.
                      if (v.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      if (v == _oldController.text) {
                        return 'New password must be different';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'Enter new password',
                      prefixIcon: const Icon(Icons.lock_reset_rounded),
                      suffixIcon: _EyeButton(
                        obscured: _obscureNew,
                        onPressed: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                  ),
                  if (_newController.text.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _StrengthMeter(password: _newController.text),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            FadeSlideIn(
              delay: const Duration(milliseconds: 180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FieldLabel('CONFIRM NEW PASSWORD', required: true),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: _obscureNew,
                    enabled: !authState.isLoading,
                    validator: (v) => v != _newController.text
                        ? 'Passwords do not match'
                        : null,
                    decoration: const InputDecoration(
                      hintText: 'Re-enter new password',
                      prefixIcon: Icon(Icons.check_circle_outline_rounded),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxxl),
            ElevatedButton(
              onPressed: authState.isLoading ? null : _submit,
              child: AnimatedSwitcher(
                duration: AppMotion.fast,
                child: authState.isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Update password'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EyeButton extends StatelessWidget {
  const _EyeButton({required this.obscured, required this.onPressed});

  final bool obscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: AnimatedSwitcher(
        duration: AppMotion.fast,
        child: Icon(
          obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          key: ValueKey(obscured),
          size: 20,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// Live password-strength feedback.
///
/// Purely advisory — the server's only hard rule is a 6-character minimum, so
/// a "weak" reading never blocks submission.
class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.password});

  final String password;

  /// 0 = weak, 1 = fair, 2 = strong.
  int get _score {
    var score = 0;
    if (password.length >= 8) score++;
    final hasLetter = password.contains(RegExp(r'[A-Za-z]'));
    final hasDigit = password.contains(RegExp(r'\d'));
    final hasSymbol = password.contains(RegExp(r'[^A-Za-z0-9]'));
    if (hasLetter && hasDigit) score++;
    if (hasSymbol && password.length >= 10) score++;
    return score.clamp(0, 2);
  }

  @override
  Widget build(BuildContext context) {
    final score = _score;
    const labels = ['Weak', 'Fair', 'Strong'];
    const colors = [AppColors.danger, AppColors.warning, AppColors.success];

    return Row(
      children: [
        ...List.generate(3, (i) {
          return Expanded(
            child: AnimatedContainer(
              duration: AppMotion.mid,
              curve: AppMotion.ease,
              height: 4,
              margin: EdgeInsets.only(right: i == 2 ? 0 : 5),
              decoration: BoxDecoration(
                color: i <= score ? colors[score] : AppColors.progressTrack,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          );
        }),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 46,
          child: Text(
            labels[score],
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors[score],
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
