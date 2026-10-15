import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/session.dart';
import '../../widgets/partner_widgets.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _obscure = true;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(partnerSessionProvider.notifier)
          .signIn(email: _email.text, password: _password.text);
      if (mounted) context.go('/');
    } on BackendException catch (e) {
      if (mounted) setState(() => _error = context.core.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final t = context.t;
    final email = await askText(
      context,
      title: t.signInForgot,
      label: t.fieldEmail,
      initial: _email.text.trim(),
      submit: t.forgotSend,
      keyboardType: TextInputType.emailAddress,
    );
    if (email == null || !mounted) return;
    try {
      await ref.read(partnerSessionProvider.notifier).sendPasswordReset(email);
      if (mounted) showSnack(context, t.signInForgotSent);
    } on BackendException catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(Space.xxl),
            children: [
              const SizedBox(height: Space.xl),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: AlghaliMark(size: 56, variant: MarkVariant.partner),
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
                validator: (v) => v == null || v.isEmpty ? core.fieldRequired : null,
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(onPressed: _forgot, child: Text(t.signInForgot)),
              ),
              if (_error != null) ...[
                InfoBanner(tone: Tone.danger, icon: Icons.error_outline, message: _error!),
                const SizedBox(height: Space.md),
              ],
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
              const SizedBox(height: Space.md),
              TextButton(onPressed: () => context.go(Routes.signUp), child: Text(t.signInApply)),
            ],
          ),
        ),
      ),
    );
  }
}

/// New partners make an account first, then apply as a shop or a technician.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

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
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(partnerSessionProvider.notifier)
          .signUp(
            name: _name.text,
            email: _email.text,
            phone: _phone.text.replaceAll(' ', ''),
            password: _password.text,
          );
      if (mounted) context.go(Routes.apply);
    } on BackendException catch (e) {
      if (mounted) setState(() => _error = context.core.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go(Routes.signIn)),
        title: Text(t.signUpTitle),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(Space.xxl),
          children: [
            Text(
              t.signUpBody,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: Space.xl),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: InputDecoration(
                labelText: t.fieldName,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (v) => (v ?? '').trim().length < 2 ? core.fieldRequired : null,
            ),
            const SizedBox(height: Space.lg),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
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
              controller: _phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: InputDecoration(
                labelText: t.fieldPhone,
                hintText: '09xxxxxxxx',
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              validator: (v) => isSudanPhone(v ?? '') ? null : core.fieldPhoneInvalid,
            ),
            const SizedBox(height: Space.lg),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.newPassword],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: t.fieldPassword,
                helperText: core.fieldPasswordWeak,
                helperMaxLines: 2,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscure ? t.showPassword : t.hidePassword,
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
              validator: (v) => v == null || v.isEmpty
                  ? core.fieldRequired
                  : isStrongPassword(v)
                  ? null
                  : core.fieldPasswordWeak,
            ),
            if (_error != null) ...[
              const SizedBox(height: Space.lg),
              InfoBanner(tone: Tone.danger, icon: Icons.error_outline, message: _error!),
            ],
            const SizedBox(height: Space.xl),
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
            TextButton(
              onPressed: () => context.go(Routes.signIn),
              child: Text(t.signUpHaveAccount),
            ),
          ],
        ),
      ),
    );
  }
}

/// Accounts with more than one shop, or a shop and a technician profile, pick which
/// home to open (switchable later).
class RoleScreen extends ConsumerWidget {
  const RoleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final session = ref.watch(partnerSessionProvider);

    Future<void> choose(PartnerRole role, [String? shopId]) async {
      await ref.read(partnerSessionProvider.notifier).chooseRole(role, shopId: shopId);
      if (context.mounted) context.go(Routes.homeOf(role));
    }

    Widget card({
      required bool selected,
      required IconData icon,
      required String title,
      required String subtitle,
      required PartnerStatus status,
      required VoidCallback onTap,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.lgAll,
          side: BorderSide(
            color: selected ? theme.colorScheme.secondary : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Row(
              children: [
                IconTile(icon: icon, size: 56, tone: Tone.brand),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (status != PartnerStatus.approved) ...[
                        const SizedBox(height: Space.xs),
                        PartnerStatusPill(status: status),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left
                      : Icons.chevron_right,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(Space.xxl),
        children: [
          Text(t.roleTitle, style: theme.textTheme.headlineSmall),
          const SizedBox(height: Space.xs),
          Text(
            t.roleBody,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Space.xxl),
          for (final s in session.shops)
            card(
              selected: session.role == PartnerRole.shop && session.shopId == s.shopId,
              icon: Icons.storefront_outlined,
              title: s.name.tr(context),
              subtitle: s.role == StaffRole.owner ? t.roleShop : t.roleShopStaff,
              status: s.status,
              onTap: () => choose(PartnerRole.shop, s.shopId),
            ),
          if (session.technician case final tech?)
            card(
              selected: session.role == PartnerRole.technician,
              icon: Icons.handyman_outlined,
              title: t.roleTechnician,
              subtitle: session.name ?? '',
              status: tech.status,
              onTap: () => choose(PartnerRole.technician),
            ),
          const SizedBox(height: Space.md),
          if (session.shops.where((s) => s.role == StaffRole.owner).length < 3)
            TextButton.icon(
              onPressed: () => context.push(Routes.applyShop),
              icon: const Icon(Icons.add_business_outlined),
              label: Text(t.applyAddShop),
            ),
          if (session.technician == null)
            TextButton.icon(
              onPressed: () => context.push(Routes.applyTech),
              icon: const Icon(Icons.handyman_outlined),
              label: Text(t.applyAsTechnician),
            ),
        ],
      ),
    );
  }
}
