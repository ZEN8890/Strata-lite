// Definisi model data untuk Barang
class Item {
  String? id; // ID dokumen dari Firestore, bisa null jika baru dibuat
  final String name;
  final String barcode;
  final dynamic quantityOrRemark; // Bisa int atau String
  final DateTime createdAt; // Tanggal dan waktu barang ditambahkan

  Item({
    this.id,
    required this.name,
    required this.barcode,
    required this.quantityOrRemark,
    required this.createdAt,
  });

  // Factory constructor untuk membuat objek Item dari Firestore DocumentSnapshot
  factory Item.fromFirestore(Map<String, dynamic> data, String id) {
    return Item(
      id: id,
      name: data['name'] as String,
      barcode: data['barcode'] as String,
      // Firestore menyimpan angka sebagai num (int atau double), atau string
      quantityOrRemark: data['quantityOrRemark'],
      createdAt: (data['createdAt'].toDate() as DateTime),
    );
  }

  // Method untuk mengubah objek Item menjadi Map<String, dynamic>
  // yang bisa disimpan ke Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'barcode': barcode,
      'quantityOrRemark': quantityOrRemark,
      'createdAt': createdAt,
    };
  }
}
