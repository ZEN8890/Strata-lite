// Path: lib/screens/group_management_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:Strata_lite/models/group.dart';
import 'package:Strata_lite/models/item.dart';
import 'dart:developer';

class GroupManagementDialog extends StatefulWidget {
  const GroupManagementDialog({super.key});

  @override
  State<GroupManagementDialog> createState() => _GroupManagementDialogState();
}

class _GroupManagementDialogState extends State<GroupManagementDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
          await _firestore.collection('groups').add({
            'name': nameController.text.trim(),
            'itemIds': [],
          });
          _showNotification(
              'Berhasil', 'Grup "${nameController.text}" berhasil dibuat.');
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
        .map((doc) => Item.fromFirestore(doc.data(), doc.id))
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
                        // Tambahkan 'await' di sini
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
