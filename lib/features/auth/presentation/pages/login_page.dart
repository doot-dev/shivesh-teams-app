import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_animations.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../providers/auth_providers.dart';

/// Field-technician sign-in: username + password.
///
/// A successful login stores a 30-day JWT, so this screen is normally seen once
/// a month at most — the router sends restored sessions straight to /home.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _userNameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _userNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    // The router redirect moves to /home on success — no manual navigation.
    await ref
        .read(authProvider.notifier)
        .login(_userNameController.text.trim(), _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(next.error!)),
              ],
            ),
            backgroundColor: AppColors.danger,
            margin: const EdgeInsets.all(AppSpacing.lg),
          ),
        );
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.blue900,
        resizeToAvoidBottomInset: true,
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.brandGradient),
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top,
                ),
                // IntrinsicHeight is REQUIRED, not decorative: the form sheet
                // below uses Expanded, and a Column inside a scroll view has
                // unbounded height, which throws "children have non-zero flex
                // but incoming height constraints are unbounded" and renders a
                // blank blue screen.
                child: IntrinsicHeight(
                  // IntrinsicHeight is REQUIRED, not decorative: the form sheet
                  // below uses Expanded, and a Column inside a scroll view has
                  // unbounded height — that combination throws "children have
                  // non-zero flex but incoming height constraints are unbounded"
                  // and renders a blank blue screen.
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // ---------- Brand header ----------
                        FadeSlideIn(
                          offset: -0.2,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: bottomInset > 0
                                  ? AppSpacing.xl
                                  : AppSpacing.huge,
                            ),
                            child: BrandMark(
                              logoSize: bottomInset > 0 ? 48 : 68,
                              compact: bottomInset > 0,
                            ),
                          ),
                        ),

                        // ---------- Form sheet ----------
                        Expanded(
                          child: FadeSlideIn(
                            delay: const Duration(milliseconds: 120),
                            offset: 0.06,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.xxl,
                                AppSpacing.xxxl,
                                AppSpacing.xxl,
                                AppSpacing.xxl,
                              ),
                              decoration: const BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(36),
                                  topRight: Radius.circular(36),
                                ),
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Welcome back',
                                      style: theme.textTheme.headlineSmall,
                                    ),
                                    const SizedBox(height: AppSpacing.xs + 2),
                                    Text(
                                      'Sign in to view your assigned orders.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: AppColors.textMuted,
                                          ),
                                    ),

                                    if (authState.sessionMessage != null) ...[
                                      const SizedBox(height: AppSpacing.xl),
                                      _SessionBanner(
                                        message: authState.sessionMessage!,
                                      ),
                                    ],

                                    const SizedBox(height: AppSpacing.xxl + 4),
                                    const FieldLabelSmall('USERNAME'),
                                    TextFormField(
                                      controller: _userNameController,
                                      textInputAction: TextInputAction.next,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      textCapitalization:
                                          TextCapitalization.none,
                                      enabled: !authState.isLoading,
                                      style: theme.textTheme.bodyLarge,
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                          ? 'Please enter your username'
                                          : null,
                                      decoration: const InputDecoration(
                                        hintText: 'e.g. rahul.jadhav',
                                        prefixIcon: Icon(
                                          Icons.person_outline_rounded,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: AppSpacing.xl),
                                    const FieldLabelSmall('PASSWORD'),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscure,
                                      textInputAction: TextInputAction.done,
                                      enabled: !authState.isLoading,
                                      style: theme.textTheme.bodyLarge,
                                      onFieldSubmitted: (_) => _handleSubmit(),
                                      validator: (v) => (v == null || v.isEmpty)
                                          ? 'Please enter your password'
                                          : null,
                                      decoration: InputDecoration(
                                        hintText: 'Enter your password',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline_rounded,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: AnimatedSwitcher(
                                            duration: AppMotion.fast,
                                            child: Icon(
                                              _obscure
                                                  ? Icons.visibility_outlined
                                                  : Icons
                                                        .visibility_off_outlined,
                                              key: ValueKey(_obscure),
                                              color: AppColors.textMuted,
                                              size: 20,
                                            ),
                                          ),
                                          onPressed: () => setState(
                                            () => _obscure = !_obscure,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: AppSpacing.xl),
                                    _TrustNote(),

                                    const SizedBox(height: AppSpacing.xxl),
                                    _SubmitButton(
                                      loading: authState.isLoading,
                                      onPressed: _handleSubmit,
                                    ),
                                    const SizedBox(height: AppSpacing.xl),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Login CTA with a built-in loading state.
///
/// The label cross-fades into a spinner instead of the button collapsing, so
/// the layout does not jump while the request is in flight.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        shadowColor: AppColors.primary.withValues(alpha: 0.4),
        elevation: loading ? 0 : 6,
      ),
      child: AnimatedSwitcher(
        duration: AppMotion.fast,
        child: loading
            ? const SizedBox(
                key: ValueKey('loading'),
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Row(
                key: const ValueKey('label'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Sign In'),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    );
  }
}

/// Reassures the technician they will not be asked to log in every shift.
class _TrustNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.blue50,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.blue100),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              "You'll stay signed in for 30 days on this device.",
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.blue800),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact uppercase label used above the login inputs.
class FieldLabelSmall extends StatelessWidget {
  const FieldLabelSmall(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 2),
      child: Text(text, style: AppTypography.overline),
    );
  }
}

/// Explains an involuntary return to login (revoked or expired token).
class _SessionBanner extends StatelessWidget {
  const _SessionBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}
