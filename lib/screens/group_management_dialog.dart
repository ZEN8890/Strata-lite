// Path: lib/screens/group_management_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:QR_Aid/models/group.dart';
import 'package:QR_Aid/models/item.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:developer';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class GroupManagementDialog extends StatefulWidget {
  const GroupManagementDialog({super.key});

  @override
  State<GroupManagementDialog> createState() => _GroupManagementDialogState();
}

class _GroupManagementDialogState extends State<GroupManagementDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey _qrKey = GlobalKey();

  Future<void> _showNotification(String title, String message,
      {bool isError = false}) async {
    if (!mounted) return;
    await Flushbar(
      titleText: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16.0,
              color: isError ? Colors.red[900] : Colors.green[900])),
      messageText: Text(message,
          style: TextStyle(
              fontSize: 14.0,
              color: isError ? Colors.red[800] : Colors.green[800])),
      flushbarPosition: FlushbarPosition.TOP,
      flushbarStyle: FlushbarStyle.FLOATING,
      backgroundColor: isError ? Colors.red[100]! : Colors.green[100]!,
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
      duration: const Duration(seconds: 3),
    ).show(context);
  }

  Future<void> _editItemClassification(String oldClassification) async {
    final newClassificationController =
        TextEditingController(text: oldClassification);

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit Nama Klasifikasi'),
        content: TextField(
          controller: newClassificationController,
          decoration: const InputDecoration(labelText: 'Nama Klasifikasi Baru'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newClassificationController.text.isNotEmpty) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final newClassificationName = newClassificationController.text.trim();
        QuerySnapshot snapshot = await _firestore
            .collection('items')
            .where('classification', isEqualTo: oldClassification)
            .get();

        WriteBatch batch = _firestore.batch();
        for (var doc in snapshot.docs) {
          batch
              .update(doc.reference, {'classification': newClassificationName});
        }
        await batch.commit();

        _showNotification('Berhasil',
            'Klasifikasi "$oldClassification" berhasil diperbarui menjadi "$newClassificationName".');
      } catch (e) {
        log('Error updating classification: $e');
        _showNotification(
            'Gagal', 'Gagal memperbarui klasifikasi. Silakan coba lagi.',
            isError: true);
      }
    }
  }

  Future<void> _deleteClassification(String classification) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text(
            'Apakah Anda yakin ingin menghapus klasifikasi "$classification"? Semua item di dalamnya akan kehilangan klasifikasinya.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        QuerySnapshot snapshot = await _firestore
            .collection('items')
            .where('classification', isEqualTo: classification)
            .get();

        WriteBatch batch = _firestore.batch();
        for (var doc in snapshot.docs) {
          batch.update(doc.reference, {'classification': null});
        }
        await batch.commit();

        _showNotification(
            'Berhasil', 'Klasifikasi "$classification" berhasil dihapus.');
      } catch (e) {
        log('Error deleting classification: $e');
        _showNotification(
            'Gagal', 'Gagal menghapus klasifikasi. Silakan coba lagi.',
            isError: true);
      }
    }
  }

  Future<void> _exportQrCode(String qrData) async {
    try {
      RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final String fileName =
          'qr_code_${DateTime.now().millisecondsSinceEpoch}.png';

      if (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux) {
        final String? resultPath = await FilePicker.platform.saveFile(
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['png'],
        );

        if (!mounted) return;

        if (resultPath != null) {
          // PERBAIKAN: Tambahkan ekstensi .png jika tidak ada
          final String finalPath = resultPath.toLowerCase().endsWith('.png')
              ? resultPath
              : '$resultPath.png';

          final File file = File(finalPath);
          await file.writeAsBytes(pngBytes);
          _showNotification(
              'Berhasil', 'QR Code berhasil disimpan ke: $finalPath');
          log('File QR Code berhasil diekspor ke: $finalPath');
        } else {
          _showNotification(
              'Ekspor Dibatalkan', 'Ekspor dibatalkan oleh pengguna.',
              isError: true);
        }
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/$fileName').create();
        await file.writeAsBytes(pngBytes);

        final success =
            await GallerySaver.saveImage(file.path, albumName: 'Strata Lite');

        if (success == true) {
          _showNotification('Berhasil', 'QR Code berhasil disimpan ke galeri.');
        } else {
          _showNotification(
              'Gagal', 'Gagal menyimpan gambar. Periksa izin aplikasi.',
              isError: true);
          log('Error saving image: $success');
        }
      }
    } catch (e) {
      _showNotification('Gagal', 'Terjadi kesalahan saat mengekspor QR code.',
          isError: true);
      log('Error exporting QR code: $e');
    }
  }

  void _showQrCodeForClassification(String classificationName) {
    String qrData = 'group:$classificationName';
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('QR Code untuk Grup "$classificationName"'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: _qrKey,
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pindai QR ini untuk melihat daftar item grup.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Tutup'),
            ),
            ElevatedButton(
              onPressed: () => _exportQrCode(qrData),
              child: const Text('Export QR'),
            ),
          ],
        );
      },
    );
  }

  // --- Fungsionalitas baru untuk mengedit item dalam grup ---
  Future<void> _editGroupItems(
      String classification, List<Item> itemsInGroup) async {
    final List<String> currentItemIds =
        itemsInGroup.map((item) => item.id!).toList();
    Set<String> selectedItemIds = Set<String>.from(currentItemIds);

    QuerySnapshot allItemsSnapshot =
        await _firestore.collection('items').orderBy('name').get();
    List<Item> allItems = allItemsSnapshot.docs
        .map((doc) =>
            Item.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit Item di Grup "$classification"'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allItems.length,
                  itemBuilder: (context, index) {
                    final item = allItems[index];
                    final isSelected = selectedItemIds.contains(item.id);
                    return CheckboxListTile(
                      title: Text(item.name),
                      subtitle: Text('Stok: ${item.quantityOrRemark}'),
                      value: isSelected,
                      onChanged: (bool? newValue) {
                        setState(() {
                          if (newValue == true) {
                            selectedItemIds.add(item.id!);
                          } else {
                            selectedItemIds.remove(item.id!);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      QuerySnapshot groupsSnapshot = await _firestore
                          .collection('groups')
                          .where('name', isEqualTo: classification)
                          .limit(1)
                          .get();

                      if (groupsSnapshot.docs.isEmpty) {
                        await _firestore.collection('groups').add({
                          'name': classification,
                          'itemIds': selectedItemIds.toList(),
                        });
                      } else {
                        await groupsSnapshot.docs.first.reference.update({
                          'itemIds': selectedItemIds.toList(),
                        });
                      }

                      Navigator.of(dialogContext).pop();
                      _showNotification('Berhasil',
                          'Item di grup "$classification" berhasil diperbarui.');
                    } catch (e) {
                      log('Error updating group items: $e');
                      if (!mounted) return;
                      _showNotification('Gagal',
                          'Gagal memperbarui item grup. Silakan coba lagi.',
                          isError: true);
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  // --- Akhir fungsionalitas baru ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Grup (Klasifikasi)'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('items').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<Item> allItems = snapshot.data!.docs
              .map((doc) => Item.fromFirestore(
                  doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          final uniqueClassifications = allItems
              .map((item) => item.classification)
              .whereType<String>()
              .toSet()
              .toList();
          uniqueClassifications.sort();

          if (uniqueClassifications.isEmpty) {
            return const Center(
                child: Text('Belum ada klasifikasi yang dibuat.'));
          }

          return ListView.builder(
            itemCount: uniqueClassifications.length,
            itemBuilder: (context, index) {
              final classification = uniqueClassifications[index];
              final itemsInGroup = allItems
                  .where((item) => item.classification == classification)
                  .toList();
              final itemsInGroupCount = itemsInGroup.length;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(classification,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$itemsInGroupCount item'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tombol baru untuk mengedit item dalam grup
                      IconButton(
                        icon: const Icon(Icons.edit_note, color: Colors.green),
                        onPressed: () =>
                            _editGroupItems(classification, itemsInGroup),
                        tooltip: 'Edit Item Grup',
                      ),
                      IconButton(
                        icon: const Icon(Icons.qr_code, color: Colors.purple),
                        onPressed: () =>
                            _showQrCodeForClassification(classification),
                        tooltip: 'Generate QR Code Grup',
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () =>
                            _editItemClassification(classification),
                        tooltip: 'Edit Klasifikasi',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteClassification(classification),
                        tooltip: 'Hapus Klasifikasi',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
