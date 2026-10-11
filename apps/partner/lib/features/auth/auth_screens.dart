import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/session.dart';

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

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await ref
        .read(partnerSessionProvider.notifier)
        .signIn(email: _email.text, password: _password.text);
    if (mounted) context.go(Routes.role);
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
              const SizedBox(height: Space.md),
              TextButton(
                onPressed: () =>
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(t.applySoon))),
                child: Text(t.signInApply),
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

/// Accounts with both roles pick which home to open (switchable later).
class RoleScreen extends ConsumerWidget {
  const RoleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final session = ref.watch(partnerSessionProvider);
    final shop = catalogue.shop(session.shopId);
    final tech = catalogue.technician(session.technicianId);

    Future<void> choose(PartnerRole role) async {
      await ref.read(partnerSessionProvider.notifier).chooseRole(role);
      if (context.mounted) context.go(Routes.homeOf(role));
    }

    Widget card(PartnerRole role, IconData icon, String title, String subtitle) => Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.lgAll,
          side: BorderSide(
            color: session.role == role
                ? theme.colorScheme.secondary
                : theme.colorScheme.outlineVariant,
            width: session.role == role ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => choose(role),
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
          card(PartnerRole.shop, Icons.storefront_outlined, t.roleShop, shop.name.tr(context)),
          card(
            PartnerRole.technician,
            Icons.handyman_outlined,
            t.roleTechnician,
            tech.name.tr(context),
          ),
        ],
      ),
    );
  }
}
