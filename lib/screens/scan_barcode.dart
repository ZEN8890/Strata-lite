// Path: lib/screens/scan_barcode.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:strata_lite/models/item.dart';
import 'package:strata_lite/models/log_entry.dart';
import 'package:strata_lite/models/group.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:audioplayers/audioplayers.dart';

class ScanBarcodeScreen extends StatefulWidget {
  const ScanBarcodeScreen({super.key});

  @override
  State<ScanBarcodeScreen> createState() => _ScanBarcodeScreenState();
}

class _ScanBarcodeScreenState extends State<ScanBarcodeScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  MobileScannerController? _scannerController;
  bool _isLoading = false;
  bool _isScanning = false;

  Timer? _notificationTimer;

  Item? _scannedItem;
  bool _isQuantityBased = true;
  String _userRole = 'staff';
  bool _isAdding = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _userRole = userData['role'] ?? 'staff';
            if (_userRole == 'staff') {
              _isAdding = false;
            } else {
              _isAdding = true;
            }
          });
          log('User role fetched: $_userRole');
        }
      } catch (e) {
        log('Error fetching user role: $e');
      }
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _quantityController.dispose();
    _remarksController.dispose();
    _scannerController?.stop();
    _scannerController?.dispose();
    _notificationTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playScanSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/Beep.mp3'));
    } catch (e) {
      log('Error playing sound: $e');
    }
  }

  void _showNotification(String title, String message, {bool isError = false}) {
    if (!context.mounted) return;

    if (_notificationTimer != null && _notificationTimer!.isActive) {
      log('Notification already active, skipping new one.');
      return;
    }

    Flushbar(
      titleText: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16.0,
          color: isError ? Colors.red[900] : Colors.green[900],
        ),
      ),
      messageText: Text(
        message,
        style: TextStyle(
          fontSize: 14.0,
          color: isError ? Colors.red[800] : Colors.green[800],
        ),
      ),
      flushbarPosition: FlushbarPosition.TOP,
      flushbarStyle: FlushbarStyle.FLOATING,
      backgroundColor: isError ? Colors.red[100]! : Colors.green[100]!,
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
      icon: Icon(
        isError ? Icons.error_outline : Icons.check_circle_outline,
        color: isError ? Colors.red[800] : Colors.green[800],
      ),
      duration: const Duration(seconds: 3),
    ).show(context);

    _notificationTimer = Timer(const Duration(seconds: 2), () {
      _notificationTimer = null;
    });
  }

  Future<void> _startScanBarcode() async {
    if (_isScanning || _isLoading) {
      log('Scan or loading already in progress.');
      return;
    }

    setState(() {
      _isScanning = true;
      _scannedItem = null;
      _barcodeController.clear();
      _quantityController.clear();
      _remarksController.clear();
    });

    try {
      await _scannerController?.start();
    } catch (e) {
      log('Error starting scanner: $e');
      setState(() {
        _isScanning = false;
      });
      _showNotification(
          'Gagal Memulai Pemindai', 'Terjadi kesalahan saat memulai kamera: $e',
          isError: true);
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (capture.barcodes.isNotEmpty) {
      final Barcode detectedBarcode = capture.barcodes.first;
      final String? barcodeValue = detectedBarcode.rawValue;

      log('Scanned barcode result: $barcodeValue (Format: ${detectedBarcode.format})');

      if (barcodeValue != null) {
        _scannerController?.stop();
        setState(() {
          _isScanning = false;
        });

        if (barcodeValue.startsWith('group:')) {
          String groupId = barcodeValue.substring(6);
          _showNotification('QR Code Grup Ditemukan', 'Memuat item grup...');
          _playScanSound();
          _showGroupItemsSelection(groupId);
        } else if (barcodeValue.length == 13) {
          _barcodeController.text = barcodeValue;
          _showNotification('Barcode Ditemukan', 'Barcode EAN-13 terdeteksi.');
          _playScanSound();
          _fetchItemDetails(barcodeValue);
        } else {
          _showNotification('Barcode Invalid',
              'Barcode tidak valid atau bukan EAN-13 / QR Code grup.',
              isError: true);
        }
      }
    }
  }

  Future<void> _fetchItemDetails(String barcode) async {
    setState(() {
      _isLoading = true;
      _scannedItem = null;
      _quantityController.clear();
      _remarksController.clear();
    });

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('items')
          .where('barcode', isEqualTo: barcode)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        DocumentSnapshot itemDoc = snapshot.docs.first;
        setState(() {
          _scannedItem = Item.fromFirestore(
              itemDoc.data() as Map<String, dynamic>, itemDoc.id);
          _isQuantityBased = _scannedItem!.quantityOrRemark is int;
          _isLoading = false;
        });
        _showNotification('Item Ditemukan',
            'Barcode: $barcode\nNama Item: ${_scannedItem!.name}');
      } else {
        setState(() {
          _isLoading = false;
        });
        _showNotification('Item Tidak Ditemukan',
            'Item dengan barcode "$barcode" tidak ditemukan.',
            isError: true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showNotification(
          'Gagal Mengambil Item', 'Error mengambil detail item: $e',
          isError: true);
      log('Error fetching item details: $e');
    }
  }

  Future<void> _showGroupItemsSelection(String groupId,
      {Map<String, bool>? selectedItems,
      Map<String, TextEditingController>? quantityControllers,
      Map<String, TextEditingController>? remarksControllers}) async {
    try {
      DocumentSnapshot groupDoc =
          await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) {
        _showNotification(
            'Grup Tidak Ditemukan', 'Grup dengan QR Code ini tidak ada.',
            isError: true);
        return;
      }
      final group = Group.fromFirestore(groupDoc);
      if (group.itemIds.isEmpty) {
        _showNotification('Grup Kosong', 'Grup ini tidak memiliki item.',
            isError: true);
        return;
      }

      final itemsSnapshot = await _firestore
          .collection('items')
          .where(FieldPath.documentId, whereIn: group.itemIds)
          .get();
      final allGroupItems = itemsSnapshot.docs
          .map((doc) =>
              Item.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      Map<String, bool> currentSelectedItems = selectedItems ?? {};
      Map<String, TextEditingController> currentQuantityControllers =
          quantityControllers ?? {};
      Map<String, TextEditingController> currentRemarksControllers =
          remarksControllers ?? {};

      for (var item in allGroupItems) {
        if (!currentSelectedItems.containsKey(item.id)) {
          currentSelectedItems[item.id!] = false;
        }
        if (item.quantityOrRemark is int) {
          if (!currentQuantityControllers.containsKey(item.id)) {
            currentQuantityControllers[item.id!] = TextEditingController();
          }
        } else {
          if (!currentRemarksControllers.containsKey(item.id)) {
            currentRemarksControllers[item.id!] = TextEditingController();
          }
        }
      }

      showDialog(
        context: context,
        builder: (dialogContext) {
          final TextEditingController searchController =
              TextEditingController();
          return StatefulBuilder(
            builder: (context, setState) {
              final filteredItems = allGroupItems.where((item) {
                final searchQuery = searchController.text.toLowerCase();
                return item.name.toLowerCase().contains(searchQuery);
              }).toList();

              return AlertDialog(
                title: Text('Pilih Item dari Grup "${group.name}"'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          labelText: 'Cari Item',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                      SizedBox(height: 10),
                      if (currentSelectedItems.values.any((element) => element))
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Item Terpilih:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            ...allGroupItems
                                .where((item) =>
                                    currentSelectedItems[item.id] == true)
                                .map((item) {
                              return Text('- ${item.name}');
                            }).toList(),
                            Divider(),
                          ],
                        ),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final isSelected =
                                currentSelectedItems[item.id] ?? false;

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CheckboxListTile(
                                  title: Text(item.name),
                                  subtitle: Text(
                                      'Stok: ${item.quantityOrRemark.toString()}'),
                                  value: isSelected,
                                  onChanged: (bool? newValue) {
                                    setState(() {
                                      currentSelectedItems[item.id!] =
                                          newValue!;
                                    });
                                  },
                                ),
                                if (isSelected)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0, vertical: 8.0),
                                    child: item.quantityOrRemark is int
                                        ? TextField(
                                            controller:
                                                currentQuantityControllers[
                                                    item.id],
                                            decoration: InputDecoration(
                                              labelText: _isAdding
                                                  ? 'Kuantitas Ditambah'
                                                  : 'Kuantitas Diambil',
                                              border:
                                                  const OutlineInputBorder(),
                                            ),
                                            keyboardType: TextInputType.number,
                                          )
                                        : TextField(
                                            controller:
                                                currentRemarksControllers[
                                                    item.id],
                                            decoration: const InputDecoration(
                                              labelText: 'Remarks Pengambilan',
                                              border: OutlineInputBorder(),
                                            ),
                                            maxLines: 3,
                                          ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Batal'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _confirmAndProcessGroupItems(
                          currentSelectedItems,
                          currentQuantityControllers,
                          allGroupItems,
                          currentRemarksControllers,
                          parentDialogContext: dialogContext);
                    },
                    child: const Text('Konfirmasi'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      log('Error fetching group items: $e');
      _showNotification(
          'Gagal Memuat Grup', 'Terjadi kesalahan saat memuat item grup.',
          isError: true);
    }
  }

  Future<void> _confirmAndProcessGroupItems(
      Map<String, bool> selectedItems,
      Map<String, TextEditingController> quantityControllers,
      List<Item> allGroupItems,
      Map<String, TextEditingController> remarksControllers,
      {required BuildContext parentDialogContext}) async {
    List<Map<String, dynamic>> itemsToProcess = [];

    for (var item in allGroupItems) {
      if (selectedItems[item.id] == true) {
        if (item.quantityOrRemark is int) {
          int? qty = int.tryParse(quantityControllers[item.id]!.text.trim());
          if (qty != null && qty > 0) {
            itemsToProcess.add({
              'item': item,
              'quantity': qty,
              'isAdding': _isAdding,
            });
          }
        } else {
          String? remark = remarksControllers[item.id]!.text.trim();
          if (remark.isNotEmpty) {
            itemsToProcess.add({
              'item': item,
              'remark': remark,
            });
          }
        }
      }
    }

    if (itemsToProcess.isEmpty) {
      _showNotification(
          'Tidak Ada Item Dipilih', 'Silakan pilih item untuk diproses.',
          isError: true);
      return;
    }

    // Menampilkan dialog konfirmasi baru dengan daftar item yang akan diproses
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Pilihan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Apakah Anda yakin ingin memproses item berikut?'),
            const SizedBox(height: 10),
            ...itemsToProcess.map((data) {
              Item item = data['item'];
              if (item.quantityOrRemark is int) {
                int qty = data['quantity'];
                return Text(
                    '- ${item.name}: ${_isAdding ? 'Tambah' : 'Ambil'} $qty');
              } else {
                return Text('- ${item.name}: Remarks "${data['remark']}"');
              }
            }).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('Kembali'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, true), // Konfirmasi dan proses
            child: const Text('Proses'),
          ),
        ],
      ),
    );
    // Tutup dialog pemilihan item sebelum memproses item.
    if (parentDialogContext.mounted) {
      Navigator.pop(parentDialogContext);
    }
    if (confirmed == true) {
      _processSelectedGroupItems(itemsToProcess);
    }
  }

  Future<void> _processSelectedGroupItems(
      List<Map<String, dynamic>> itemsToProcess) async {
    setState(() {
      _isLoading = true;
    });

    for (var data in itemsToProcess) {
      Item item = data['item'];
      try {
        if (item.quantityOrRemark is int) {
          int quantity = data['quantity'];
          int newQuantity = _isAdding ? quantity : -quantity;

          if (!_isAdding && quantity > item.quantityOrRemark) {
            _showNotification('Gagal', 'Stok ${item.name} tidak cukup.',
                isError: true);
            continue;
          }

          await _firestore.collection('items').doc(item.id).update({
            'quantityOrRemark': FieldValue.increment(newQuantity),
          });

          DocumentSnapshot updatedItemDoc =
              await _firestore.collection('items').doc(item.id).get();
          int? updatedStock = (updatedItemDoc.data()
              as Map<String, dynamic>)['quantityOrRemark'];

          String operation = _isAdding ? 'Ditambahkan' : 'Dikurangi';
          _showNotification('Sukses',
              'Stok ${item.name} $operation sebanyak $quantity. Sisa: $updatedStock');

          await _addLogEntry(item, newQuantity, remainingStock: updatedStock);
        } else {
          String remarks = data['remark'];
          await _addLogEntry(item, remarks, remarks: remarks);
          _showNotification('Sukses', 'Pengambilan ${item.name} dicatat.');
        }
      } catch (e) {
        log('Error processing item ${item.name}: $e');
        _showNotification('Error', 'Gagal memproses item ${item.name}.',
            isError: true);
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _processItem() async {
    if (_scannedItem == null) {
      _showNotification('Item Belum Dipindai',
          'Silakan pindai atau masukkan barcode item terlebih dahulu.',
          isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isQuantityBased) {
        int? quantity = int.tryParse(_quantityController.text.trim());
        if (quantity == null || quantity <= 0) {
          _showNotification(
              'Kuantitas Invalid', 'Kuantitas harus lebih dari 0.',
              isError: true);
          return;
        }

        int newQuantity = _isAdding ? quantity : -quantity;

        if (!_isAdding && quantity > _scannedItem!.quantityOrRemark) {
          _showNotification('Stok Tidak Cukup',
              'Kuantitas yang diambil ($quantity) melebihi stok yang tersedia (${_scannedItem!.quantityOrRemark}).',
              isError: true);
          return;
        }

        await _firestore.collection('items').doc(_scannedItem!.id).update({
          'quantityOrRemark': FieldValue.increment(newQuantity),
        });

        DocumentSnapshot updatedItemDoc =
            await _firestore.collection('items').doc(_scannedItem!.id).get();
        int? updatedStock =
            (updatedItemDoc.data() as Map<String, dynamic>)['quantityOrRemark'];

        String operation = _isAdding ? 'Ditambahkan' : 'Dikurangi';

        _showNotification('Stok Berhasil $operation',
            'Stok item "${_scannedItem!.name}" $operation sebanyak $quantity. Sisa Stok: $updatedStock',
            isError: false);

        await _addLogEntry(
          _scannedItem!,
          newQuantity,
          remarks: _remarksController.text.trim().isEmpty
              ? null
              : _remarksController.text.trim(),
          remainingStock: updatedStock,
        );
      } else {
        String remarks = _remarksController.text.trim();
        if (remarks.isEmpty) {
          _showNotification(
              'Remarks Kosong', 'Remarks tidak boleh kosong untuk item ini.',
              isError: true);
          return;
        }
        await _addLogEntry(_scannedItem!, remarks, remarks: remarks);
        _showNotification('Pengambilan Dicatat',
            'Pengambilan item "${_scannedItem!.name}" dicatat.',
            isError: false);
      }
    } catch (e) {
      _showNotification('Gagal Memproses Stok', 'Gagal memproses stok: $e',
          isError: true);
      log('Error processing stock: $e');
    } finally {
      _clearAllForms();
    }
  }

  void _clearAllForms() {
    setState(() {
      _barcodeController.clear();
      _quantityController.clear();
      _remarksController.clear();
      _isLoading = false;
      _scannedItem = null;
    });
  }

  Future<void> _addLogEntry(Item item, dynamic quantityOrRemark,
      {String? remarks, int? remainingStock}) async {
    User? currentUser = _auth.currentUser;
    String staffName = currentUser?.email ?? 'Unknown User';
    String staffDepartment = 'Unknown Department';

    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          staffName = userData['name'] ?? currentUser.email ?? 'Unknown User';
          staffDepartment = userData['department'] ?? 'Unknown Department';
        }
      } catch (e) {
        log('Error fetching staff details for log entry: $e');
      }
    }

    String? itemClassification = item.classification;

    LogEntry newLog = LogEntry(
      itemName: item.name,
      quantityOrRemark: quantityOrRemark,
      timestamp: DateTime.now(),
      staffName: staffName,
      staffDepartment: staffDepartment,
      remarks: remarks,
      remainingStock: remainingStock,
      itemClassification: itemClassification,
    );

    try {
      await _firestore.collection('log_entries').add(newLog.toFirestore());
      log('Log entry added for ${item.name}');
    } catch (e) {
      _showNotification(
          'Gagal Mencatat Log', 'Gagal mencatat log pengambilan: $e',
          isError: true);
      log('Error adding log entry: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double scanWindowSize = screenSize.width * 0.7;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: _isScanning
            ? Stack(
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onBarcodeDetected,
                    scanWindow: Rect.fromCenter(
                      center:
                          Offset(screenSize.width / 2, screenSize.height / 2),
                      width: scanWindowSize,
                      height: scanWindowSize,
                    ),
                  ),
                  _buildScanWindowOverlay(scanWindowSize, scanWindowSize),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isScanning = false;
                        });
                        _scannerController?.stop();
                      },
                      child: const Text('Batalkan Scan'),
                    ),
                  ),
                ],
              )
            : ListView(
                children: [
                  if (_userRole == 'admin')
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _isAdding = true;
                                    _scannedItem = null;
                                  });
                                },
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('Tambah'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isAdding
                                      ? Colors.green[600]
                                      : Colors.grey[300],
                                  foregroundColor:
                                      _isAdding ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _isAdding = false;
                                    _scannedItem = null;
                                  });
                                },
                                icon: const Icon(Icons.remove_circle_outline),
                                label: const Text('Ambil'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: !_isAdding
                                      ? Colors.red[600]
                                      : Colors.grey[300],
                                  foregroundColor: !_isAdding
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _barcodeController,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Barcode atau QR Code',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: const Color(0xFFF3F4F6),
                              suffixIcon: _isLoading || _isScanning
                                  ? const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.qr_code_scanner),
                                      onPressed: _startScanBarcode,
                                    ),
                            ),
                          ),
                          if (_scannedItem != null) ...[
                            const SizedBox(height: 20),
                            Text(
                              'Nama Barang: ${_scannedItem!.name}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                                'Stok Tersedia: ${_scannedItem!.quantityOrRemark.toString()}',
                                style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 20),
                            if (_isQuantityBased &&
                                _scannedItem!.quantityOrRemark is int)
                              TextFormField(
                                controller: _quantityController,
                                decoration: InputDecoration(
                                  labelText: _isAdding
                                      ? 'Kuantitas yang Ditambah'
                                      : 'Kuantitas yang Diambil',
                                  border: const OutlineInputBorder(),
                                  filled: true,
                                  fillColor: const Color(0xFFF3F4F6),
                                  prefixIcon: Icon(_isAdding
                                      ? Icons.add_box_outlined
                                      : Icons.remove_circle_outline),
                                  hintText: 'Masukkan kuantitas',
                                ),
                                keyboardType: TextInputType.number,
                                onFieldSubmitted: (value) {
                                  FocusScope.of(context).unfocus();
                                },
                              )
                            else
                              TextFormField(
                                controller: _remarksController,
                                decoration: const InputDecoration(
                                  labelText: 'Remarks Pengambilan',
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Color(0xFFF3F4F6),
                                  prefixIcon: Icon(Icons.notes),
                                  hintText: 'Contoh: Untuk P3K di ruang rapat',
                                ),
                                maxLines: 3,
                                onFieldSubmitted: (value) {
                                  FocusScope.of(context).unfocus();
                                },
                              ),
                            const SizedBox(height: 20),
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: _processItem,
                                icon:
                                    Icon(_isAdding ? Icons.add : Icons.remove),
                                label: Text(_isAdding
                                    ? 'Tambah barang'
                                    : 'Ambil barang'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _isAdding ? Colors.green : Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ] else if (!_isLoading)
                            const Center(
                              child: Text(
                                'Pindai barcode atau QR code untuk memproses barang.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildScanWindowOverlay(double width, double height) {
    return Positioned.fill(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 4),
                borderRadius: BorderRadius.circular(16.0),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(
                  top:
                      MediaQuery.of(context).size.height / 2 - height / 2 - 50),
              child: const Text(
                'Arahkan kamera ke barcode',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
