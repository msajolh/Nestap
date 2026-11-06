import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/nestap_logo.dart';
import '../providers/auth_controller.dart';

/// Passwordless sign-in: email or phone → 6-digit code.
///
/// Phones: logo on top, form below. Tablets/desktop: brand panel on the left,
/// form on the right.
class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.isCompact) {
      return const Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: AppSpacing.xxl),
                NestapLogo(height: 44),
                SizedBox(height: AppSpacing.xxxl),
                _SignInForm(),
              ],
            ),
          ),
        ),
      );
    }

    return const Scaffold(
      body: Row(
        children: [
          Expanded(child: _BrandPanel()),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: SizedBox(width: 420, child: _SignInForm()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const NestapLogo(height: 56),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'The Touch of a\nModern Home',
              style: text.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                height: 1.15,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Switches, sockets, curtains and scenes. One app for your whole home.',
              style: text.titleMedium?.copyWith(color: AppColors.gray300),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignInForm extends ConsumerStatefulWidget {
  const _SignInForm();

  @override
  ConsumerState<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends ConsumerState<_SignInForm> {
  final _target = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;

  @override
  void dispose() {
    _target.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final auth = ref.read(authControllerProvider.notifier);
    try {
      if (_codeSent) {
        await auth.verifyOtp(target: _target.text, code: _code.text);
        // The router redirects to /home on Authenticated.
      } else {
        await auth.requestOtp(_target.text);
        if (mounted) setState(() => _codeSent = true);
      }
    } on Object catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final demo = ref.watch(appConfigProvider).useDemoBackend;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _codeSent ? 'Check your messages' : 'Welcome home',
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _codeSent
                ? 'We sent a 6-digit code to ${_target.text.trim()}.'
                : 'Sign in or create an account with your email or phone number.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            controller: _target,
            enabled: !_codeSent && !_busy,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email, AutofillHints.telephoneNumber],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email or phone',
              hintText: 'you@example.com or +8801…',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_codeSent) ...[
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _code,
              enabled: !_busy,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 8),
              decoration: const InputDecoration(
                labelText: '6-digit code',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(_codeSent ? 'Verify and continue' : 'Send code'),
          ),
          if (_codeSent)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _codeSent = false;
                        _code.clear();
                      }),
              child: const Text('Use a different email or phone'),
            ),
          if (demo) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Demo mode: no server configured. Any email and any 6-digit code will work.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
