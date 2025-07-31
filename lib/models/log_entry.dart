// Path: lib/models/log_entry.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class LogEntry {
  String? id;
  final String itemName;
  final String barcode;
  final dynamic
      quantityOrRemark; // Reverted to dynamic to be consistent with the Item model
  final DateTime timestamp;
  final String staffName;
  final String staffDepartment;
  final String? remarks;

  LogEntry({
    this.id,
    required this.itemName,
    required this.barcode,
    required this.quantityOrRemark, // Reverted to dynamic
    required this.timestamp,
    required this.staffName,
    required this.staffDepartment,
    this.remarks,
  });

  factory LogEntry.fromFirestore(
      Map<String, dynamic> firestoreData, String docId) {
    return LogEntry(
      id: docId,
      itemName: firestoreData['itemName'] ?? '',
      barcode: firestoreData['barcode'] ?? '',
      quantityOrRemark:
          firestoreData['quantityOrRemark'], // Reverted to dynamic
      timestamp: (firestoreData['timestamp'] as Timestamp).toDate(),
      staffName: firestoreData['staffName'] ?? '',
      staffDepartment: firestoreData['staffDepartment'] ?? '',
      remarks: firestoreData['remarks'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'itemName': itemName,
      'barcode': barcode,
      'quantityOrRemark': quantityOrRemark, // Reverted to dynamic
      'timestamp': timestamp,
      'staffName': staffName,
      'staffDepartment': staffDepartment,
      'remarks': remarks,
    };
  }
}
