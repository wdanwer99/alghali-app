import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/session.dart';

/// Edits the buyer's name and phone. With [askPhone] it explains that a phone is needed
/// before ordering (shops and technicians call it). True when saved.
Future<bool> showProfileSheet(BuildContext context, {bool askPhone = false}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProfileSheet(askPhone: askPhone),
    ) ??
    false;

class _ProfileSheet extends ConsumerStatefulWidget {
  const _ProfileSheet({required this.askPhone});

  final bool askPhone;

  @override
  ConsumerState<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends ConsumerState<_ProfileSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: ref.read(sessionProvider).name ?? '');
  late final _phone = TextEditingController(text: localPhone(ref.read(sessionProvider).phone));
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .updateProfile(name: _name.text.trim(), phone: _phone.text.replaceAll(' ', ''));
      if (mounted) Navigator.pop(context, true);
    } on BackendException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final core = context.core;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.lg),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.profileTitle, style: Theme.of(context).textTheme.titleLarge),
                if (widget.askPhone) ...[
                  const SizedBox(height: Space.md),
                  InfoBanner(tone: Tone.info, message: core.errPhoneRequired),
                ],
                const SizedBox(height: Space.lg),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: t.fieldName,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? core.fieldRequired : null,
                ),
                const SizedBox(height: Space.lg),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  autofocus: widget.askPhone,
                  decoration: InputDecoration(
                    labelText: t.fieldPhone,
                    helperText: t.fieldPhoneHelp,
                    hintText: '09XXXXXXXX',
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? core.fieldRequired
                      : isSudanPhone(v)
                      ? null
                      : core.fieldPhoneInvalid,
                ),
                const SizedBox(height: Space.xl),
                FilledButton(onPressed: _saving ? null : _save, child: Text(t.profileSave)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
