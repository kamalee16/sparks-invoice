import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/client.dart';

class ClientService {
  final CollectionReference _col = FirebaseFirestore.instance.collection('clients');

  Future<DocumentReference> addClient(Client client) => _col.add(client.toJson());

  Future<void> updateClient(Client client) => _col.doc(client.id).update(client.toJson());

  Future<void> archiveClient(String id) => _col.doc(id).update({'isArchived': true});

  Future<void> restoreClient(String id) => _col.doc(id).update({'isArchived': false});

  Future<Client?> getClient(String id) async {
    final doc = await _col.doc(id).get();
    if (doc.exists) return Client.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
    return null;
  }

  Stream<List<Client>> getClients({bool includeArchived = false}) {
    return _col.snapshots().map((s) => s.docs
        .map((d) => Client.fromFirestore(d.data() as Map<String, dynamic>, d.id))
        .where((c) => includeArchived || !c.isArchived)
        .toList());
  }

  Future<bool> isDuplicateName(String name, {String? excludeId}) async {
    final snap = await _col.where('name', isEqualTo: name).get();
    return snap.docs.any((d) => d.id != excludeId);
  }
}
