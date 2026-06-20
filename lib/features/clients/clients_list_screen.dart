import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/logout_button.dart';
import '../../core/widgets/search_field.dart';
import '../../models/client.dart';
import '../../services/client_service.dart';
import '../../providers/clients_stats_provider.dart';

final _clientsProvider = FutureProvider<List<Client>>((ref) {
  return ClientService().getAll();
});

enum _Sort { nom, ca, impaye }

class ClientsListScreen extends ConsumerStatefulWidget {
  const ClientsListScreen({super.key});

  @override
  ConsumerState<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends ConsumerState<ClientsListScreen> {
  String _query = '';
  _Sort _sort = _Sort.nom;

  bool _match(Client c) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return c.nom.toLowerCase().contains(q) ||
        (c.telephone ?? '').toLowerCase().contains(q) ||
        (c.adresse ?? '').toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(_clientsProvider);
    final stats = ref.watch(clientsStatsProvider).valueOrNull ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          PopupMenuButton<_Sort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Trier',
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Sort.nom, child: Text('Trier par nom')),
              PopupMenuItem(value: _Sort.ca, child: Text('Trier par CA')),
              PopupMenuItem(value: _Sort.impaye, child: Text('Trier par impayé')),
            ],
          ),
          const LogoutButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/clients/new'),
        child: const Icon(Icons.add),
      ),
      body: clients.when(
        data: (all) {
          if (all.isEmpty) return const _EmptyState();
          final list = all.where(_match).toList();
          double impaye(Client c) => stats[c.id]?.impaye ?? 0;
          double ca(Client c) => stats[c.id]?.caFacture ?? 0;
          switch (_sort) {
            case _Sort.nom:
              list.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
            case _Sort.ca:
              list.sort((a, b) => ca(b).compareTo(ca(a)));
            case _Sort.impaye:
              list.sort((a, b) => impaye(b).compareTo(impaye(a)));
          }
          return Column(
            children: [
              SearchField(
                hint: 'Rechercher (nom, téléphone, adresse)',
                onChanged: (v) => setState(() => _query = v),
              ),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('Aucun résultat', style: TextStyle(color: AppColors.s400)))
                    : RefreshIndicator(
                        color: AppColors.g500,
                        onRefresh: () async {
                          ref.invalidate(_clientsProvider);
                          ref.invalidate(clientsStatsProvider);
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) =>
                              _ClientTile(client: list[i], stat: stats[list[i].id]),
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
      ),
    );
  }
}

class _ClientTile extends StatelessWidget {
  final Client client;
  final ClientStat? stat;
  const _ClientTile({required this.client, this.stat});

  @override
  Widget build(BuildContext context) {
    final impaye = stat?.impaye ?? 0;
    final ca = stat?.caFacture ?? 0;
    return ListTile(
      onTap: () => context.go('/clients/${client.id}'),
      tileColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.s100),
      ),
      leading: CircleAvatar(
        backgroundColor: AppColors.g100,
        child: Text(
          client.nom[0].toUpperCase(),
          style: const TextStyle(color: AppColors.g700, fontWeight: FontWeight.w800),
        ),
      ),
      title: Text(client.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(client.telephone ?? client.adresse ?? '—'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (ca > 0)
            Text(Formatters.fcfa(ca),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.g700)),
          if (impaye > 0)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Doit ${Formatters.fcfa(impaye)}',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.orange)),
            ),
          if (ca == 0 && impaye == 0)
            const Icon(Icons.chevron_right, color: AppColors.s300),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.people_outline, size: 64, color: AppColors.s200),
        SizedBox(height: 12),
        Text('Aucun client', style: TextStyle(color: AppColors.s400, fontSize: 16)),
        SizedBox(height: 4),
        Text('Appuie sur + pour ajouter un client',
            style: TextStyle(color: AppColors.s300, fontSize: 12)),
      ],
    ),
  );
}
