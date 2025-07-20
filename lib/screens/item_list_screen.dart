import 'package:flutter/material.dart';
import 'package:excel/excel.dart'; // Import Excel package
import 'package:file_picker/file_picker.dart'; // Import File Picker
import 'package:path_provider/path_provider.dart'; // Untuk mendapatkan direktori penyimpanan
import 'dart:io'; // Untuk File
import 'package:permission_handler/permission_handler.dart'; // Untuk izin penyimpanan
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore
import 'package:Strata_lite/models/item.dart'; // Import model Item
import 'dart:developer'; // Untuk log.log()
import 'package:device_info_plus/device_info_plus.dart'; // Import device_info_plus
import 'package:flutter/foundation.dart'; // Untuk defaultTargetPlatform
import 'package:another_flushbar/flushbar.dart'; // Import Flushbar
import 'dart:async'; // Untuk Timer
import 'package:intl/intl.dart'; // Untuk DateFormat

class ItemListScreen extends StatefulWidget {
  const ItemListScreen({super.key});

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Timer? _notificationTimer; // Timer untuk mengontrol frekuensi notifikasi
  bool _isLoadingExport = false; // Untuk indikator loading ekspor
  bool _isLoadingImport = false; // Untuk indikator loading impor

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _notificationTimer?.cancel(); // Batalkan timer notifikasi
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  // Fungsi untuk menampilkan notifikasi yang diperbagus (sama seperti di TakeItemScreen)
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

  // Fungsi Pembantu untuk Meminta Izin Penyimpanan
  Future<bool> _requestStoragePermission(BuildContext context) async {
    log('Requesting storage permission...');
    if (defaultTargetPlatform == TargetPlatform.android) {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

      if (androidInfo.version.sdkInt >= 30) {
        var status = await Permission.manageExternalStorage.request();
        log('MANAGE_EXTERNAL_STORAGE Permission Status: $status');
        log('Status details: isGranted=${status.isGranted}, isDenied=${status.isDenied}, isPermanentlyDenied=${status.isPermanentlyDenied}, isRestricted=${status.isRestricted}, isLimited=${status.isLimited}, isProvisional=${status.isProvisional}');

        if (status.isGranted) {
          return true;
        } else if (status.isPermanentlyDenied) {
          if (!context.mounted) return false;
          _showPermissionDeniedDialog(
              context,
              'Izin "Kelola Semua File" diperlukan',
              'Untuk mengimpor/mengekspor file Excel, aplikasi membutuhkan izin "Kelola Semua File". Harap izinkan secara manual di Pengaturan Aplikasi.');
          return false;
        } else {
          if (!context.mounted) return false;
          _showNotification(
              'Izin Ditolak', 'Izin ditolak. Tidak dapat melanjutkan.',
              isError: true);
          return false;
        }
      } else {
        var status = await Permission.storage.request();
        log('STORAGE Permission Status (Legacy): $status');
        log('Status details: isGranted=${status.isGranted}, isDenied=${status.isDenied}, isPermanentlyDenied=${status.isPermanentlyDenied}, isRestricted=${status.isRestricted}, isLimited=${status.isLimited}, isProvisional=${status.isProvisional}');
        if (status.isGranted) {
          return true;
        } else if (status.isPermanentlyDenied) {
          if (!context.mounted) return false;
          _showPermissionDeniedDialog(context, 'Izin Penyimpanan Diperlukan',
              'Untuk mengimpor/mengekspor file Excel, aplikasi membutuhkan izin penyimpanan. Harap izinkan secara manual di Pengaturan Aplikasi.');
          return false;
        } else {
          if (!context.mounted) return false;
          _showNotification(
              'Izin Ditolak', 'Izin ditolak. Tidak dapat melanjutkan.',
              isError: true);
          return false;
        }
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      var status = await Permission.photos.request();
      if (status.isGranted) {
        return true;
      } else if (status.isPermanentlyDenied) {
        if (!context.mounted) return false;
        _showPermissionDeniedDialog(context, 'Izin Foto Diperlukan',
            'Untuk mengimpor/mengekspor file, aplikasi membutuhkan izin akses foto. Harap izinkan secara manual di Pengaturan Aplikasi.');
        return false;
      } else {
        if (!context.mounted) return false;
        _showNotification(
            'Izin Ditolak', 'Izin ditolak. Tidak dapat melanjutkan.',
            isError: true);
        return false;
      }
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      log('Platform desktop, assuming file access is granted.');
      return true;
    }
    _showNotification('Platform Tidak Didukung',
        'Platform ini tidak didukung untuk operasi file.',
        isError: true);
    return false;
  }

  void _showPermissionDeniedDialog(
      BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  Future<String?> _getExportPath(BuildContext context) async {
    String fileName =
        'Daftar_Barang_Strata_Lite_${DateTime.now().millisecondsSinceEpoch}.xlsx';

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        String publicDownloadRoot = '/storage/emulated/0/Download';
        Directory publicDownloadDir = Directory(publicDownloadRoot);

        if (!await publicDownloadDir.exists()) {
          await publicDownloadDir.create(recursive: true);
        }

        String publicDownloadPath = '${publicDownloadDir.path}/$fileName';
        log('Attempting to export to explicit public Downloads (Android): $publicDownloadPath');
        return publicDownloadPath;
      } catch (e) {
        log('Error directly accessing public Downloads (hardcoded path): $e');
        _showNotification('Akses Downloads Gagal',
            'Gagal mengakses folder Downloads publik secara langsung. Mencoba folder internal.',
            isError: true);
      }

      Directory? appSpecificDir = await getApplicationDocumentsDirectory();
      if (appSpecificDir != null) {
        String appSpecificPath = '${appSpecificDir.path}/$fileName';
        log('Falling back to app-specific directory: $appSpecificPath');
        _showNotification('Ekspor Internal',
            'Mengekspor ke folder internal aplikasi karena akses Downloads publik gagal total.',
            isError: false);
        return appSpecificPath;
      }

      _showNotification('Direktori Tidak Ditemukan',
          'Tidak dapat menemukan direktori penyimpanan yang cocok untuk ekspor di Android.',
          isError: true);
      return null;
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      Directory? downloadsDirectory = await getDownloadsDirectory();
      if (downloadsDirectory != null) {
        String desktopDownloadPath = '${downloadsDirectory.path}/$fileName';
        log('Attempting to export to desktop Downloads: $desktopDownloadPath');
        return desktopDownloadPath;
      }
      _showNotification('Direktori Tidak Ditemukan',
          'Tidak dapat menemukan direktori Downloads di desktop.',
          isError: true);
      return null;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      Directory? downloadsDirectory = await getDownloadsDirectory();
      if (downloadsDirectory != null) {
        String iOSDownloadPath = '${downloadsDirectory.path}/$fileName';
        log('Attempting to export to iOS app files directory: $iOSDownloadPath');
        return iOSDownloadPath;
      }
      _showNotification('Direktori Tidak Ditemukan',
          'Tidak dapat menemukan direktori penyimpanan di iOS.',
          isError: true);
      return null;
    }

    _showNotification('Platform Tidak Didukung',
        'Platform ini tidak didukung untuk operasi file.',
        isError: true);
    return null;
  }

  Future<void> _exportDataToExcel(BuildContext context) async {
    setState(() {
      _isLoadingExport = true;
    });

    bool hasPermission = await _requestStoragePermission(context);
    if (!hasPermission) {
      setState(() {
        _isLoadingExport = false;
      });
      return;
    }

    String? path = await _getExportPath(context);
    if (!context.mounted) {
      setState(() {
        _isLoadingExport = false;
      });
      return;
    }
    if (path == null) {
      setState(() {
        _isLoadingExport = false;
      });
      return;
    }

    try {
      var excel = Excel.createExcel();
      // Dapatkan nama sheet default yang secara otomatis dibuat saat inisialisasi.
      String defaultSheetName = excel.getDefaultSheet()!;

      // Dapatkan objek sheet default
      Sheet sheetObject = excel.sheets[defaultSheetName]!;

      // Hapus semua data dari sheet default jika ada.
      for (int i = 0; i < sheetObject.maxRows; i++) {
        sheetObject.removeRow(0);
      }

      // Tambahkan header ke sheet default
      sheetObject.appendRow([
        TextCellValue('Nama Barang'),
        TextCellValue('Barcode'),
        TextCellValue('Kuantitas/Remarks'),
        TextCellValue('Tanggal Ditambahkan')
      ]);

      QuerySnapshot snapshot =
          await _firestore.collection('items').orderBy('name').get();
      List<Item> itemsToExport = snapshot.docs.map((doc) {
        return Item.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      for (var item in itemsToExport) {
        String formattedDate =
            '${item.createdAt.day.toString().padLeft(2, '0')}-${item.createdAt.month.toString().padLeft(2, '0')}-${item.createdAt.year}';
        sheetObject.appendRow([
          TextCellValue(item.name),
          TextCellValue(item.barcode),
          TextCellValue(item.quantityOrRemark.toString()),
          TextCellValue(formattedDate)
        ]);
      }

      // Setelah semua data ditambahkan, ganti nama sheet default menjadi "Daftar Barang"
      if (defaultSheetName != 'Daftar Barang') {
        excel.rename(defaultSheetName, 'Daftar Barang');
        log('Sheet "$defaultSheetName" berhasil diubah namanya menjadi "Daftar Barang".');
      }

      List<int>? fileBytes = excel.save();
      if (fileBytes != null) {
        File file = File(path);
        await file.writeAsBytes(fileBytes);
        if (!context.mounted) return;
        _showNotification('Ekspor Berhasil', 'Data berhasil diekspor ke: $path',
            isError: false);
        log('File Excel berhasil diekspor ke: $path');
      } else {
        if (!context.mounted) return;
        _showNotification('Ekspor Gagal', 'Gagal membuat file Excel.',
            isError: true);
      }
    } catch (e) {
      if (!context.mounted) return;
      _showNotification('Ekspor Gagal', 'Error saat ekspor data: $e',
          isError: true);
      log('Error saat ekspor data: $e');
    } finally {
      setState(() {
        _isLoadingExport = false;
      });
    }
  }

  Future<void> _importDataFromExcel(BuildContext context) async {
    setState(() {
      _isLoadingImport = true; // Tampilkan loading saat impor
    });

    bool hasPermission = await _requestStoragePermission(context);
    if (!hasPermission) {
      setState(() {
        _isLoadingImport = false;
      });
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (!context.mounted) {
        setState(() {
          _isLoadingImport = false;
        });
        return;
      }

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        var bytes = file.readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        List<Item> importedItems = [];
        // Asumsi sheet pertama adalah yang berisi data (atau sheet bernama "Daftar Barang" jika ada)
        String? sheetName = excel.tables.keys.firstWhere(
          (key) => key == 'Daftar Barang',
          orElse: () => excel.tables.keys
              .first, // Fallback ke sheet pertama jika 'Daftar Barang' tidak ditemukan
        );

        if (sheetName == null) {
          // Jika tidak ada sheet sama sekali (walaupun mustahil dengan Excel.decodeBytes)
          _showNotification('Impor Gagal',
              'File Excel tidak memiliki sheet yang dapat dibaca.',
              isError: true);
          setState(() {
            _isLoadingImport = false;
          });
          return;
        }

        Sheet table = excel.tables[sheetName]!;

        for (int i = 1; i < (table.rows.length); i++) {
          // Mulai dari baris 1 untuk melewati header
          var row = table.rows[i];
          if (row.length >= 3) {
            // Pastikan ada cukup kolom data
            String name = row[0]?.value?.toString() ?? '';
            String barcode = row[1]?.value?.toString() ?? '';
            String quantityOrRemarkString = row[2]?.value?.toString() ?? '';

            dynamic quantityOrRemark;
            if (int.tryParse(quantityOrRemarkString) != null) {
              quantityOrRemark = int.parse(quantityOrRemarkString);
            } else {
              quantityOrRemark = quantityOrRemarkString;
            }

            if (name.isNotEmpty && barcode.isNotEmpty) {
              importedItems.add(Item(
                name: name,
                barcode: barcode,
                quantityOrRemark: quantityOrRemark,
                createdAt: DateTime.now(),
              ));
            }
          }
        }

        if (importedItems.isEmpty) {
          _showNotification('Impor Gagal',
              'Tidak ada data valid yang ditemukan untuk diimpor dari file Excel.',
              isError: true);
          setState(() {
            _isLoadingImport = false;
          });
          return;
        }

        WriteBatch batch = _firestore.batch();
        for (var item in importedItems) {
          // Opsional: Cek duplikasi barcode saat impor
          QuerySnapshot existingItems = await _firestore
              .collection('items')
              .where('barcode', isEqualTo: item.barcode)
              .limit(1)
              .get();
          if (existingItems.docs.isNotEmpty) {
            // Jika barcode duplikat, bisa lewati atau update yang sudah ada
            log('Skipping duplicate item during import: ${item.name} with barcode ${item.barcode}');
            continue;
          }
          batch.set(_firestore.collection('items').doc(), item.toFirestore());
        }
        await batch.commit();

        if (!context.mounted) {
          setState(() {
            _isLoadingImport = false;
          });
          return;
        }
        _showNotification('Impor Berhasil',
            'Berhasil mengimpor ${importedItems.length} item dari Excel!',
            isError: false);
        log('Item yang diimpor dan disimpan ke Firestore: $importedItems');
      } else {
        _showNotification('Impor Dibatalkan', 'Pemilihan file dibatalkan.',
            isError: true);
      }
    } catch (e) {
      if (!context.mounted) return;
      _showNotification('Impor Gagal', 'Error saat impor data: $e',
          isError: true);
      log('Error saat impor data: $e');
    } finally {
      setState(() {
        _isLoadingImport = false;
      });
    }
  }

  Future<void> _editItem(BuildContext context, Item item) async {
    TextEditingController nameController =
        TextEditingController(text: item.name);
    TextEditingController barcodeController =
        TextEditingController(text: item.barcode);
    TextEditingController quantityOrRemarkController =
        TextEditingController(text: item.quantityOrRemark.toString());
    bool isQuantityBasedEdit = item.quantityOrRemark is int;

    Item? updatedItem = await showDialog<Item>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: const Text('Edit Barang'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration:
                          const InputDecoration(labelText: 'Nama Barang'),
                    ),
                    TextField(
                      controller: barcodeController,
                      decoration:
                          const InputDecoration(labelText: 'Barcode EAN-13'),
                      keyboardType: TextInputType.number,
                    ),
                    Row(
                      children: [
                        const Text('Item Berbasis Kuantitas?'),
                        Switch(
                          value: isQuantityBasedEdit,
                          onChanged: (bool value) {
                            setStateSB(() {
                              isQuantityBasedEdit = value;
                            });
                          },
                        ),
                      ],
                    ),
                    isQuantityBasedEdit
                        ? TextField(
                            controller: quantityOrRemarkController,
                            decoration:
                                const InputDecoration(labelText: 'Kuantitas'),
                            keyboardType: TextInputType.number,
                          )
                        : TextField(
                            controller: quantityOrRemarkController,
                            decoration:
                                const InputDecoration(labelText: 'Remarks'),
                            maxLines: 3,
                          ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Batal'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Simpan'),
                  onPressed: () {
                    dynamic newQuantityOrRemark;
                    if (isQuantityBasedEdit) {
                      newQuantityOrRemark =
                          int.tryParse(quantityOrRemarkController.text.trim());
                      if (newQuantityOrRemark == null ||
                          newQuantityOrRemark <= 0) {
                        _showNotification('Kuantitas Invalid',
                            'Kuantitas harus berupa angka positif.',
                            isError: true);
                        return;
                      }
                    } else {
                      newQuantityOrRemark =
                          quantityOrRemarkController.text.trim();
                      if (newQuantityOrRemark.isEmpty) {
                        _showNotification(
                            'Remarks Kosong', 'Remarks tidak boleh kosong.',
                            isError: true);
                        return;
                      }
                    }

                    if (nameController.text.trim().isEmpty ||
                        barcodeController.text.trim().isEmpty) {
                      _showNotification('Input Tidak Lengkap',
                          'Nama barang dan barcode tidak boleh kosong.',
                          isError: true);
                      return;
                    }

                    Navigator.of(dialogContext).pop(Item(
                      id: item.id,
                      name: nameController.text.trim(),
                      barcode: barcodeController.text.trim(),
                      quantityOrRemark: newQuantityOrRemark,
                      createdAt: item.createdAt,
                    ));
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (updatedItem != null && updatedItem.id != null) {
      try {
        await _firestore
            .collection('items')
            .doc(updatedItem.id)
            .update(updatedItem.toFirestore());
        if (!context.mounted) return;
        _showNotification('Berhasil Diperbarui',
            'Barang "${updatedItem.name}" berhasil diperbarui!',
            isError: false);
      } catch (e) {
        if (!context.mounted) return;
        _showNotification('Gagal Memperbarui', 'Gagal memperbarui barang: $e',
            isError: true);
        log('Error updating item: $e');
      }
    }
  }

  Future<void> _deleteItem(BuildContext context, String itemId) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Konfirmasi Hapus'),
          content: const Text('Apakah Anda yakin ingin menghapus barang ini?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: const Text('Hapus', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        await _firestore.collection('items').doc(itemId).delete();
        if (!context.mounted) return;
        _showNotification('Berhasil Dihapus', 'Barang berhasil dihapus!',
            isError: false);
      } catch (e) {
        if (!context.mounted) return;
        _showNotification('Gagal Menghapus', 'Gagal menghapus barang: $e',
            isError: true);
        log('Error deleting item: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            // Menggunakan Column untuk mengelompokkan filter
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                // Card untuk pencarian
                margin: EdgeInsets.zero,
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari barang...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              Card(
                // Card untuk tombol aksi (Ekspor, Impor) - Tombol Filter dihapus
                margin: EdgeInsets.zero,
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Tombol Filter Dihapus dari sini
                      Expanded(
                        child: ElevatedButton.icon(
                          // Tombol Ekspor
                          onPressed: _isLoadingExport
                              ? null
                              : () => _exportDataToExcel(context),
                          icon: _isLoadingExport
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.upload_file), // Ganti ikon
                          label: Text(_isLoadingExport
                              ? 'Mengekspor...'
                              : 'Ekspor Excel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          // Tombol Impor
                          onPressed: _isLoadingImport
                              ? null
                              : () => _importDataFromExcel(context),
                          icon: _isLoadingImport
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(
                                  Icons.download_for_offline), // Ganti ikon
                          label: Text(_isLoadingImport
                              ? 'Mengimpor...'
                              : 'Impor Excel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.indigo, // Warna lain untuk impor
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Bagian Daftar Barang
              const Text('Daftar Barang Inventaris:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('items').orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                    child: Text('Belum ada barang diinventaris.'));
              }

              List<Item> allItems = snapshot.data!.docs.map((doc) {
                return Item.fromFirestore(
                    doc.data() as Map<String, dynamic>, doc.id);
              }).toList();

              List<Item> filteredItems = allItems.where((item) {
                final String lowerCaseQuery = _searchQuery.toLowerCase();
                return item.name.toLowerCase().contains(lowerCaseQuery) ||
                    item.barcode.toLowerCase().contains(lowerCaseQuery);
              }).toList();

              if (filteredItems.isEmpty && _searchQuery.isNotEmpty) {
                return const Center(child: Text('Barang tidak ditemukan.'));
              }
              if (filteredItems.isEmpty && _searchQuery.isEmpty) {
                return const Center(
                    child: Text('Belum ada barang diinventaris.'));
              }

              return ListView.builder(
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 3, // Tambahkan sedikit elevasi
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10)), // Sudut membulat
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10), // Padding dalam ListTile
                      title: Text(
                        item.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.blueAccent),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Barcode: ${item.barcode}',
                              style: const TextStyle(fontSize: 14)),
                          Text(
                            item.quantityOrRemark is int
                                ? 'Stok: ${item.quantityOrRemark}' // Jika kuantitas adalah int
                                : 'Jenis: Tidak Bisa Dihitung (Remarks: ${item.quantityOrRemark})', // Jika remarks adalah string
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                              'Ditambahkan: ${DateFormat('dd-MM-yyyy HH:mm').format(item.createdAt)}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: 'Edit Barang',
                            onPressed: () => _editItem(context, item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Hapus Barang',
                            onPressed: () => _deleteItem(context, item.id!),
                          ),
                        ],
                      ),
                      onTap: () {
                        // Tidak ada aksi khusus saat tap pada ListTile, bisa ditambahkan jika perlu
                        log('Detail item ${item.name} diklik');
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
