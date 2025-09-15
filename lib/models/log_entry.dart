// Path: lib/models/log_entry.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class LogEntry {
  String? id;
  final String itemName;
  final dynamic quantityOrRemark;
  final DateTime timestamp;
  final String staffName;
  final String staffDepartment;
  final String? remarks;
  final int? remainingStock;
  final String? itemClassification;

  LogEntry({
    this.id,
    required this.itemName,
    required this.quantityOrRemark,
    required this.timestamp,
    required this.staffName,
    required this.staffDepartment,
    this.remarks,
    this.remainingStock,
    this.itemClassification,
  });

  factory LogEntry.fromFirestore(
      Map<String, dynamic> firestoreData, String docId) {
    return LogEntry(
      id: docId,
      itemName: firestoreData['itemName'] ?? '',
      quantityOrRemark: firestoreData['quantityOrRemark'],
      timestamp: (firestoreData['timestamp'] as Timestamp).toDate(),
      staffName: firestoreData['staffName'] ?? '',
      staffDepartment: firestoreData['staffDepartment'] ?? '',
      remarks: firestoreData['remarks'],
      remainingStock: firestoreData['remainingStock'] as int?,
      itemClassification: firestoreData['itemClassification'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'itemName': itemName,
      'quantityOrRemark': quantityOrRemark,
      'timestamp': timestamp,
      'staffName': staffName,
      'staffDepartment': staffDepartment,
      'remarks': remarks,
      'remainingStock': remainingStock,
      'itemClassification': itemClassification,
    };
  }
}
