import 'package:flutter/material.dart';
import '../models/client.dart';
import '../services/client_service.dart';
import '../theme/app_colors.dart';
import 'client_form_screen.dart';

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({Key? key}) : super(key: key);
  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  final ClientService _svc = ClientService();
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients', style: TextStyle(fontWeight: FontWeight.bold)), 
        automaticallyImplyLeading: false
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Search clients...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _search.clear(); setState(() => _query = ''); })
                  : null,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Client>>(
            stream: _svc.getClients(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final all = snap.data ?? [];
              final clients = all.where((c) {
                final q = _query.toLowerCase();
                return c.name.toLowerCase().contains(q) || c.email.toLowerCase().contains(q) || c.contactPerson.toLowerCase().contains(q);
              }).toList();
              if (clients.isEmpty) return _empty();
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: clients.length,
                itemBuilder: (_, i) => _ClientCard(client: clients[i], svc: _svc),
              );
            },
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-add-client',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientFormScreen())),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Client', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _empty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.people_outline_rounded, size: 72, color: Colors.grey.shade300),
    const SizedBox(height: 16),
    Text(_query.isEmpty ? 'No clients yet' : 'No matching clients', style: const TextStyle(fontSize: 16, color: Colors.grey)),
  ]));
}

class _ClientCard extends StatelessWidget {
  final Client client;
  final ClientService svc;
  const _ClientCard({required this.client, required this.svc});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onBg = Theme.of(context).colorScheme.onSurface;
    final subColor = Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 9), // Rule 3
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF00E5CC).withOpacity(0.03),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientFormScreen(client: client))),
        onLongPress: () => _archive(context),
        child: Padding(
          padding: const EdgeInsets.all(12), // Rule 3
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start, // Rule 6
            children: [
              Container(
                width: 56, height: 52,
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(client.name[0].toUpperCase(), 
                    style: TextStyle(color: primary, fontWeight: FontWeight.w900, fontSize: 22),
                    maxLines: 1, // Rule 2
                    overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 12), // Rule 6
              Expanded( // Rule 1
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(client.name, 
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: onBg, letterSpacing: -0.5),
                      maxLines: 1, // Rule 2
                      overflow: TextOverflow.ellipsis),
                  if (client.contactPerson.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(client.contactPerson, 
                        style: TextStyle(color: subColor, fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 1, // Rule 2
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.email_rounded, size: 14, color: subColor.withOpacity(0.6)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(client.email, 
                        style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.w500), 
                        maxLines: 1, // Rule 2
                        overflow: TextOverflow.ellipsis)),
                  ]),
                ])),
              const SizedBox(width: 8), // Rule 6
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.15), 
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(client.currency, 
                      style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w900),
                      maxLines: 1, // Rule 2
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(height: 12),
                IconButton(
                  icon: Icon(Icons.archive_rounded, color: AppColors.danger.withOpacity(0.7), size: 24),
                  onPressed: () => _archive(context),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _archive(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Archive Client'),
      content: const Text('This will archive the client. Existing invoices will retain client details. Continue?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            print("START LOADING (Archive)");
            Navigator.pop(context);
            try {
              await svc.archiveClient(client.id!);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${client.name} archived'), behavior: SnackBarBehavior.floating));
              }
            } catch (e) {
              print("ARCHIVE ERROR: $e");
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error archiving: $e'), backgroundColor: Colors.red));
              }
            } finally {
              print("STOP LOADING (Archive)");
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size(80, 40)),
          child: const Text('Archive'),
        ),
      ],
    ));
  }
}
