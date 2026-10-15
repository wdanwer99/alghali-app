import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/account.dart';
import 'address_sheet.dart';

/// The buyer's saved places for deliveries and fittings.
class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.accountAddresses)),
      body: AsyncBody(
        value: ref.watch(addressesProvider),
        onRefresh: () => ref.refresh(addressesProvider.future),
        data: (list) => list.isEmpty
            ? ListView(
                children: [
                  EmptyState(
                    icon: Icons.location_on_outlined,
                    title: t.addressesEmpty,
                    message: t.addressNewBody,
                  ),
                ],
              )
            : ListView.separated(
                padding: Space.pageInsets,
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                itemBuilder: (context, i) {
                  final a = list[i];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(a.label.tr(context), style: theme.textTheme.titleSmall),
                      subtitle: Text(
                        [
                          if (a.description.tr(context).isNotEmpty) a.description.tr(context),
                          if (a.distanceKm > 0)
                            t.addressFromStreet(context.core.distance(a.distanceKm)),
                        ].join('\n'),
                      ),
                      trailing: IconButton(
                        tooltip: context.core.actionRemove,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          try {
                            await ref.read(addressesProvider.notifier).remove(a.id);
                          } on BackendException catch (e) {
                            if (context.mounted) showError(context, e);
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: FilledButton.icon(
          onPressed: () => showAddressSheet(context),
          icon: const Icon(Icons.add_location_alt_outlined),
          label: Text(t.addressNew),
        ),
      ),
    );
  }
}
