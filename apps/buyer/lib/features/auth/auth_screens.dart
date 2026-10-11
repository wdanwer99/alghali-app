import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/session.dart';

/// After signing in: continue to [next] if given, otherwise go back.
void _leave(BuildContext context, String? next) {
  if (next != null) {
    context.pushReplacement(next);
  } else if (context.canPop()) {
    context.pop();
  } else {
    context.go(Routes.home);
  }
}

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.next});

  final String? next;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _obscure = true;
  var _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await ref.read(sessionProvider.notifier).signIn(email: _email.text, password: _password.text);
    if (!mounted) return;
    final name = ref.read(sessionProvider).name ?? '';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.t.signInWelcome(name))));
    _leave(context, widget.next);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(Space.xxl),
            children: [
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: AlghaliMark(size: 52),
              ),
              const SizedBox(height: Space.xl),
              Text(t.signInTitle, style: theme.textTheme.headlineMedium),
              Text(
                t.signInSubtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Space.xxl),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: t.fieldEmail,
                  prefixIcon: const Icon(Icons.mail_outline),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? core.fieldRequired
                    : isEmail(v)
                    ? null
                    : core.fieldEmailInvalid,
              ),
              const SizedBox(height: Space.lg),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: t.fieldPassword,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? t.showPassword : t.hidePassword,
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (v) => v == null || v.isEmpty
                    ? core.fieldRequired
                    : isStrongPassword(v)
                    ? null
                    : core.fieldPasswordWeak,
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () =>
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(t.signInForgotSent))),
                  child: Text(t.signInForgot),
                ),
              ),
              const SizedBox(height: Space.md),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(t.signInSubmit),
              ),
              const SizedBox(height: Space.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(t.signInNoAccount, style: theme.textTheme.bodyMedium),
                  TextButton(
                    onPressed: () => context.pushReplacement(
                      Uri(path: Routes.signUp, queryParameters: {'next': ?widget.next}).toString(),
                    ),
                    child: Text(t.signInCreate),
                  ),
                ],
              ),
              const SizedBox(height: Space.lg),
              InfoBanner(
                tone: Tone.neutral,
                icon: Icons.science_outlined,
                message: t.signInDemoHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key, this.next});

  final String? next;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  var _obscure = true;
  var _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await ref
        .read(sessionProvider.notifier)
        .signUp(name: _name.text, email: _email.text, phone: _phone.text, password: _password.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.t.signInWelcome(_name.text.trim()))));
    _leave(context, widget.next);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    String? required(String? v) => v == null || v.trim().isEmpty ? core.fieldRequired : null;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(Space.xxl),
            children: [
              Text(t.signUpTitle, style: theme.textTheme.headlineMedium),
              const SizedBox(height: Space.xxl),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: t.fieldName,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: required,
              ),
              const SizedBox(height: Space.lg),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: t.fieldEmail,
                  prefixIcon: const Icon(Icons.mail_outline),
                ),
                validator: (v) => required(v) ?? (isEmail(v!) ? null : core.fieldEmailInvalid),
              ),
              const SizedBox(height: Space.lg),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.telephoneNumber],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: t.fieldPhone,
                  helperText: t.fieldPhoneHelp,
                  hintText: '09XXXXXXXX',
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                validator: (v) => required(v) ?? (isSudanPhone(v!) ? null : core.fieldPhoneInvalid),
              ),
              const SizedBox(height: Space.lg),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: t.fieldPassword,
                  helperText: core.fieldPasswordWeak,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? t.showPassword : t.hidePassword,
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (v) =>
                    required(v) ?? (isStrongPassword(v!) ? null : core.fieldPasswordWeak),
              ),
              const SizedBox(height: Space.xxl),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(t.signUpSubmit),
              ),
              const SizedBox(height: Space.md),
              Text(t.signUpTerms, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
              const SizedBox(height: Space.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(t.signUpHaveAccount, style: theme.textTheme.bodyMedium),
                  TextButton(
                    onPressed: () => context.pushReplacement(
                      Uri(path: Routes.signIn, queryParameters: {'next': ?widget.next}).toString(),
                    ),
                    child: Text(t.accountSignIn),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
