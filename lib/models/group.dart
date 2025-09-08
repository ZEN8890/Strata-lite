// Path: lib/models/group.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  String? id;
  final String name;
  final List<dynamic> itemIds; // List of item document IDs

  Group({
    this.id,
    required this.name,
    this.itemIds =
        const [], // itemIds sekarang bersifat opsional dengan nilai default
  });

  factory Group.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Group(
      id: doc.id,
      name: data['name'] ?? '',
      itemIds: data['itemIds'] ?? [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'itemIds': itemIds,
    };
  }
}
