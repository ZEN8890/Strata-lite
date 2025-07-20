import 'package:cloud_firestore/cloud_firestore.dart';

class LogEntry {
  String? id; // ID dokumen dari Firestore
  final String itemName;
  final String barcode;
  final dynamic quantityOrRemark; // Bisa int atau String
  final DateTime timestamp; // Tanggal dan waktu pengambilan
  final String staffName;
  final String staffDepartment;
  final String? remarks; // Remarks tambahan untuk pengambilan (opsional)

  LogEntry({
    this.id,
    required this.itemName,
    required this.barcode,
    required this.quantityOrRemark,
    required this.timestamp,
    required this.staffName,
    required this.staffDepartment,
    this.remarks,
  });

  // Factory constructor untuk membuat objek LogEntry dari Firestore DocumentSnapshot
  factory LogEntry.fromFirestore(Map<String, dynamic> data, String id) {
    return LogEntry(
      id: id,
      itemName: data['itemName'] as String,
      barcode: data['barcode'] as String,
      quantityOrRemark: data['quantityOrRemark'],
      timestamp: (data['timestamp'] as Timestamp)
          .toDate(), // Konversi Timestamp Firestore ke DateTime
      staffName: data['staffName'] as String,
      staffDepartment: data['staffDepartment'] as String,
      remarks: data['remarks'] as String?,
    );
  }

  // Method untuk mengubah objek LogEntry menjadi Map<String, dynamic>
  Map<String, dynamic> toFirestore() {
    return {
      'itemName': itemName,
      'barcode': barcode,
      'quantityOrRemark': quantityOrRemark,
      'timestamp': Timestamp.fromDate(
          timestamp), // Konversi DateTime ke Timestamp Firestore
      'staffName': staffName,
      'staffDepartment': staffDepartment,
      'remarks': remarks,
    };
  }
}
