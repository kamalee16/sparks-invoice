import 'package:flutter/material.dart';
import '../models/client.dart';
import '../services/client_service.dart';
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
      appBar: AppBar(title: const Text('Clients'), automaticallyImplyLeading: false),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                itemCount: clients.length,
                itemBuilder: (_, i) => _ClientCard(client: clients[i], svc: _svc),
              );
            },
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientFormScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Client'),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientFormScreen(client: client))),
        onLongPress: () => _archive(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.indigo.withOpacity(0.1),
              child: Text(client.name[0].toUpperCase(), style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(client.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              if (client.contactPerson.isNotEmpty) Text(client.contactPerson, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.email_outlined, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Expanded(child: Text(client.email, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis)),
              ]),
              if (client.phone.isNotEmpty) Row(children: [
                Icon(Icons.phone_outlined, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(client.phone, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                child: Text(client.currency, style: const TextStyle(color: Colors.indigo, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              IconButton(
                icon: Icon(Icons.archive_outlined, color: Colors.red.shade300, size: 20),
                onPressed: () => _archive(context),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
            ]),
          ]),
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
