import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/primary_button.dart';
import 'auth_controller.dart';

/// The only unauthenticated screen. There is no sign-up: the owner account is
/// created by hand in the Supabase dashboard.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final success = await ref
        .read(loginControllerProvider.notifier)
        .signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );

    if (!mounted || !success) return;
    context.go(AppRoutes.home);
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (Validators.email(email) != null) {
      context.showFailure('Enter your email address first, then tap again.');
      return;
    }

    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Reset password?',
      message: 'We will email a password reset link to $email.',
      confirmLabel: 'Send link',
    );
    if (!confirmed || !mounted) return;

    await ref.read(loginControllerProvider.notifier).sendPasswordReset(email);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);

    ref.listen<LoginState>(loginControllerProvider, (
      LoginState? previous,
      LoginState next,
    ) {
      final info = next.infoMessage;
      if (info != null && info != previous?.infoMessage) {
        context.showSuccess(info);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _LoginHeader(),
                    AppSpacing.gapXl,
                    if (state.errorMessage != null) ...<Widget>[
                      ErrorBanner(message: state.errorMessage!),
                      AppSpacing.gapLg,
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enabled: !state.submitting,
                      autofillHints: const <String>[AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'owner@example.com',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: Validators.email,
                      onChanged: (_) => ref
                          .read(loginControllerProvider.notifier)
                          .clearMessages(),
                      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                    ),
                    AppSpacing.gapLg,
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      obscureText: _obscure,
                      enabled: !state.submitting,
                      textInputAction: TextInputAction.done,
                      autofillHints: const <String>[AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                        ),
                      ),
                      validator: Validators.password,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    AppSpacing.gapSm,
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: state.submitting ? null : _forgotPassword,
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    AppSpacing.gapMd,
                    PrimaryButton(
                      label: 'Login',
                      loading: state.submitting,
                      onPressed: _submit,
                    ),
                    AppSpacing.gapXl,
                    Text(
                      'Only the business owner can sign in.',
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          height: 76,
          width: 76,
          decoration: BoxDecoration(
            color: context.colors.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Icon(
            Icons.how_to_reg_rounded,
            size: 38,
            color: context.colors.onPrimaryContainer,
          ),
        ),
        AppSpacing.gapLg,
        Text('Attendance', style: context.text.headlineMedium),
        AppSpacing.gapXs,
        Text(
          'Daily staff attendance, in one place',
          style: context.text.bodyMedium?.copyWith(color: context.mutedColor),
        ),
      ],
    );
  }
}
