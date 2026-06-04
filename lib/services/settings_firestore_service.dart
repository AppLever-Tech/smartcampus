import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsItem {
  final String id;
  final String name;
  final String? code; // Optional field for Course Type (e.g., PCC)
  final String? description; // Optional field for Batch (e.g., 2024-2026 Batch)

  SettingsItem({required this.id, required this.name, this.code, this.description});

  factory SettingsItem.fromFirestore(String id, Map<String, dynamic> data) {
    return SettingsItem(
      id: id,
      name: data['name'] ?? '',
      code: data['code'],
      description: data['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (code != null) 'code': code,
      if (description != null) 'description': description,
    };
  }
}

class SettingsFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<SettingsItem>> getItems(String collection) {
    return _firestore.collection(collection).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return SettingsItem.fromFirestore(doc.id, doc.data());
      }).toList();
    });
  }

  Future<void> addItem(String collection, {required String name, String? code, String? description}) async {
    final data = {
      'name': name,
      if (code != null) 'code': code,
      if (description != null) 'description': description,
    };
    await _firestore.collection(collection).add(data);
  }

  Future<void> updateItem(String collection, String id, {required String name, String? code, String? description}) async {
    final data = {
      'name': name,
      if (code != null) 'code': code,
      if (description != null) 'description': description,
    };
    await _firestore.collection(collection).doc(id).update(data);
  }

  Future<void> deleteItem(String collection, String id) async {
    await _firestore.collection(collection).doc(id).delete();
  }
}
