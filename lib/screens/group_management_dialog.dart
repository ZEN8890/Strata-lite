// Path: lib/screens/group_management_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:strata_lite/models/group.dart';
import 'package:strata_lite/models/item.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:developer';
import 'package:gallery_saver/gallery_saver.dart'; // Ganti import ini
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
  final GlobalKey _qrKey = GlobalKey(); // Kunci untuk menangkap widget

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
      backgroundColor: isError ? Colors.red[100]! : Colors.green[100]!,
      duration: const Duration(seconds: 3),
    ).show(context);
  }

  Future<void> _createOrEditGroup({Group? group}) async {
    final nameController = TextEditingController(text: group?.name);
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(group == null ? 'Buat Grup Baru' : 'Edit Nama Grup'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Nama Grup'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
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
        if (group == null) {
          final docRef = await _firestore.collection('groups').add({
            'name': nameController.text.trim(),
            'itemIds': [],
          });
          final newGroup =
              Group(id: docRef.id, name: nameController.text.trim());
          _showNotification(
              'Berhasil', 'Grup "${newGroup.name}" berhasil dibuat.');
          // Tampilkan QR Code secara otomatis
          if (mounted) {
            _showQrCodeForGroup(newGroup);
          }
        } else {
          await _firestore.collection('groups').doc(group.id).update({
            'name': nameController.text.trim(),
          });
          _showNotification('Berhasil', 'Grup berhasil diperbarui.');
        }
      } catch (e) {
        log('Error creating/editing group: $e');
        _showNotification(
            'Gagal', 'Gagal membuat/mengedit grup. Silakan coba lagi.',
            isError: true);
      }
    }
  }

  Future<void> _deleteGroup(String groupId) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: const Text(
            'Apakah Anda yakin ingin menghapus grup ini? Semua item di dalamnya akan kehilangan grupnya.'),
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
        await _firestore.collection('groups').doc(groupId).delete();
        _showNotification('Berhasil', 'Grup berhasil dihapus.');
      } catch (e) {
        log('Error deleting group: $e');
        _showNotification('Gagal', 'Gagal menghapus grup. Silakan coba lagi.',
            isError: true);
      }
    }
  }

  Future<void> _manageItemsInGroup(Group group) async {
    final itemsSnapshot = await _firestore.collection('items').get();
    final allItems = itemsSnapshot.docs
        .map((doc) =>
            Item.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    Set<String> selectedItemIds = Set<String>.from(group.itemIds);
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Atur Item untuk "${group.name}"'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  itemCount: allItems.length,
                  itemBuilder: (context, index) {
                    final item = allItems[index];
                    final isSelected = selectedItemIds.contains(item.id);
                    return CheckboxListTile(
                      title: Text(item.name),
                      subtitle: Text('Barcode: ${item.barcode}'),
                      value: isSelected,
                      onChanged: (bool? newValue) {
                        setState(() {
                          if (newValue == true) {
                            selectedItemIds.add(item.id!);
                          } else {
                            selectedItemIds.remove(item.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _firestore
                          .collection('groups')
                          .doc(group.id)
                          .update({
                        'itemIds': selectedItemIds.toList(),
                      });
                      if (context.mounted) {
                        await _showNotification(
                            'Berhasil', 'Item di grup berhasil diperbarui.');
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      log('Error saving group items: $e');
                      if (context.mounted) {
                        _showNotification(
                            'Gagal', 'Gagal menyimpan perubahan. Coba lagi.',
                            isError: true);
                      }
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

  // Metode untuk mengekspor QR code ke galeri
  Future<void> _exportQrCode() async {
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
        // Logic for desktop platforms using file_picker
        final String? resultPath = await FilePicker.platform.saveFile(
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['png'],
        );

        if (!mounted) return;

        if (resultPath != null) {
          final File file = File(resultPath);
          await file.writeAsBytes(pngBytes);
          _showNotification(
              'Berhasil', 'QR Code berhasil disimpan ke: $resultPath');
          log('File QR Code berhasil diekspor ke: $resultPath');
        } else {
          _showNotification(
              'Ekspor Dibatalkan', 'Ekspor dibatalkan oleh pengguna.',
              isError: true);
        }
      } else {
        // Logic for mobile platforms (Android & iOS)
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

  // Tambahkan method baru untuk menampilkan QR Code
  void _showQrCodeForGroup(Group group) {
    if (group.id == null) {
      _showNotification('Error', 'ID grup tidak valid.', isError: true);
      return;
    }
    String qrData = 'group:${group.id}';
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('QR Code untuk Grup "${group.name}"'),
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
              onPressed: _exportQrCode,
              child: const Text('Export QR'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Grup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createOrEditGroup(),
            tooltip: 'Tambah Grup Baru',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('groups').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snapshot.data!.docs
              .map((doc) => Group.fromFirestore(doc))
              .toList();
          if (groups.isEmpty) {
            return const Center(child: Text('Belum ada grup yang dibuat.'));
          }

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(group.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${group.itemIds.length} item'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tombol QR Code baru
                      IconButton(
                        icon: const Icon(Icons.qr_code, color: Colors.purple),
                        onPressed: () => _showQrCodeForGroup(group),
                        tooltip: 'Generate QR Code Grup',
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _createOrEditGroup(group: group),
                        tooltip: 'Edit Grup',
                      ),
                      IconButton(
                        icon: const Icon(Icons.group_add, color: Colors.green),
                        onPressed: () => _manageItemsInGroup(group),
                        tooltip: 'Atur Item di Grup',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteGroup(group.id!),
                        tooltip: 'Hapus Grup',
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
