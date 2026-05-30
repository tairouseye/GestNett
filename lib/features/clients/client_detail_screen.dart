import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/client.dart';
import '../../services/client_service.dart';

class ClientDetailScreen extends StatefulWidget {
  final String clientId;
  const ClientDetailScreen({super.key, required this.clientId});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  Client? _client;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await ClientService().getById(widget.clientId);
    if (mounted) setState(() { _client = c; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_client?.nom ?? 'Client'),
        actions: [
          if (_client != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.go('/clients/${widget.clientId}/edit'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _client == null
              ? const Center(child: Text('Client introuvable'))
              : _ClientBody(client: _client!),
    );
  }
}

class _ClientBody extends StatelessWidget {
  final Client client;
  const _ClientBody({required this.client});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoCard(client: client),
        const SizedBox(height: 16),
        _ActionRow(clientId: client.id),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Client client;
  const _InfoCard({required this.client});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informations', style: Theme.of(context).textTheme.titleMedium),
            const Divider(height: 20),
            _Row(label: 'Nom / Société', value: client.nom),
            if (client.contact != null)
              _Row(label: 'Contact', value: client.contact!),
            if (client.telephone != null)
              _Row(label: 'Téléphone', value: client.telephone!),
            if (client.email != null)
              _Row(label: 'Email', value: client.email!),
            if (client.adresse != null)
              _Row(label: 'Adresse', value: client.adresse!),
            if (client.ninea != null)
              _Row(label: 'NINEA', value: client.ninea!),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(color: AppColors.s400, fontSize: 12)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ],
    ),
  );
}

class _ActionRow extends StatelessWidget {
  final String clientId;
  const _ActionRow({required this.clientId});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => context.go('/invoices/new?clientId=$clientId'),
          icon: const Icon(Icons.receipt_long_outlined, size: 18),
          label: const Text('Nouvelle facture'),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => context.go('/markets/new'),
          icon: const Icon(Icons.handshake_outlined, size: 18),
          label: const Text('Nouveau marché'),
        ),
      ),
    ],
  );
}
