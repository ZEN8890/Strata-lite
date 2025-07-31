// Path: lib/models/item.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Item {
  String? id;
  final String name;
  final String barcode;
  final dynamic
      quantityOrRemark; // Reverted to dynamic to handle both int (quantity) and String (remarks)
  final DateTime createdAt;
  final DateTime? expiryDate;

  Item({
    this.id,
    required this.name,
    required this.barcode,
    required this.quantityOrRemark, // Reverted to dynamic
    required this.createdAt,
    this.expiryDate,
  });

  // Factory constructor from Firestore document
  factory Item.fromFirestore(Map<String, dynamic> firestoreData, String docId) {
    return Item(
      id: docId,
      name: firestoreData['name'] ?? '',
      barcode: firestoreData['barcode'] ?? '',
      quantityOrRemark:
          firestoreData['quantityOrRemark'], // Reverted to dynamic
      createdAt: (firestoreData['createdAt'] as Timestamp).toDate(),
      expiryDate: (firestoreData['expiryDate'] as Timestamp?)?.toDate(),
    );
  }

  // Method to convert Item object to a map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'barcode': barcode,
      'quantityOrRemark': quantityOrRemark, // Reverted to dynamic
      'createdAt': createdAt,
      'expiryDate': expiryDate,
    };
  }
}
