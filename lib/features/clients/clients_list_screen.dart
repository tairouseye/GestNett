import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/client.dart';
import '../../services/client_service.dart';

final _clientsProvider = FutureProvider<List<Client>>((ref) {
  return ClientService().getAll();
});

class ClientsListScreen extends ConsumerWidget {
  const ClientsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(_clientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {/* TODO: search */},
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/clients/new'),
        child: const Icon(Icons.add),
      ),
      body: clients.when(
        data: (list) => list.isEmpty
            ? const _EmptyState()
            : RefreshIndicator(
                color: AppColors.g500,
                onRefresh: () async => ref.invalidate(_clientsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ClientTile(client: list[i]),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
      ),
    );
  }
}

class _ClientTile extends StatelessWidget {
  final Client client;
  const _ClientTile({required this.client});

  @override
  Widget build(BuildContext context) {
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
      trailing: const Icon(Icons.chevron_right, color: AppColors.s300),
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
