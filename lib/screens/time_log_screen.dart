// Path: lib/screens/time_log_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:QR_Aid/models/log_entry.dart';
import 'package:QR_Aid/models/item.dart';
import 'dart:developer';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:another_flushbar/flushbar.dart';
import 'package:excel/excel.dart'
    as excel_lib; // Diberi prefix untuk mengatasi konflik TextSpan
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

class TimeLogScreen extends StatefulWidget {
  const TimeLogScreen({super.key});

  @override
  State<TimeLogScreen> createState() => _TimeLogScreenState();
}

class _TimeLogScreenState extends State<TimeLogScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Timer? _notificationTimer;
  bool _isLoadingExport = false;
  bool _isLoadingDelete = false;

  StreamSubscription? _classificationSubscription;

  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;
  String? _selectedClassification;
  String _selectedTransactionType = 'Semua';

  List<String> _dynamicClassifications = ['Semua Klasifikasi'];
  bool _isClassificationsLoading = true;

  // State untuk mengontrol tampilan/penyembunyian filter lanjutan
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadClassifications();

    // Set default selected classification
    _selectedClassification = _dynamicClassifications.first;
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _notificationTimer?.cancel();
    _classificationSubscription?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  void _showNotification(
    String title,
    String message, {
    bool isError = false,
  }) {
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

  Future<void> _loadClassifications() async {
    _classificationSubscription?.cancel();

    setState(() {
      _isClassificationsLoading = true;
    });

    try {
      _classificationSubscription = _firestore
          .collection('log_entries')
          .snapshots()
          .listen((logsSnapshot) {
        Set<String> uniqueClassifications = {};

        for (var doc in logsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final classification = data['itemClassification'];
          if (classification is String && classification.isNotEmpty) {
            uniqueClassifications.add(classification);
          }
        }

        if (mounted) {
          setState(() {
            _dynamicClassifications = [
              'Semua Klasifikasi',
              ...uniqueClassifications.toList()..sort()
            ];

            if (_selectedClassification != null &&
                !_dynamicClassifications.contains(_selectedClassification)) {
              _selectedClassification = 'Semua Klasifikasi';
            } else {
              _selectedClassification ??= _dynamicClassifications.first;
            }

            _isClassificationsLoading = false;
          });
          log('Dynamic classifications updated (Stream): $_dynamicClassifications');
        }
      }, onError: (e) {
        log('Error loading classifications stream: $e');
        if (mounted) {
          setState(() {
            _dynamicClassifications = ['Semua Klasifikasi'];
            _selectedClassification = _dynamicClassifications.first;
            _isClassificationsLoading = false;
          });
          _showNotification(
            'Error',
            'Gagal memuat daftar klasifikasi secara real-time.',
            isError: true,
          );
        }
      });
    } catch (e) {
      log('Initial error setting up classifications stream: $e');
      if (mounted) {
        setState(() {
          _dynamicClassifications = ['Semua Klasifikasi'];
          _selectedClassification = _dynamicClassifications.first;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context,
      {required bool isStartDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _selectedStartDate = picked;
          if (_selectedEndDate != null && _selectedEndDate!.isBefore(picked)) {
            _selectedEndDate = picked;
          }
        } else {
          _selectedEndDate = picked;
          if (_selectedStartDate != null &&
              _selectedStartDate!.isAfter(picked)) {
            _selectedStartDate = picked;
          }
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context,
      {required bool isStartTime}) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _selectedStartTime = picked;
        } else {
          _selectedEndTime = picked;
        }
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedStartDate = null;
      _selectedEndDate = null;
      _selectedStartTime = null;
      _selectedEndTime = null;
      _selectedClassification = _dynamicClassifications.first;
      _selectedTransactionType = 'Semua';
    });
    _showNotification('Filter Direset', 'Semua filter telah dihapus.');
  }

  // --- Fungsi Bantuan untuk UI ---

  Widget _buildFilterTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        title,
        style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool isLoading,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : Icon(icon),
      label: Text(isLoading ? 'Memproses...' : label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: 4,
      ),
    );
  }

  // --- FUNGSI UTAMA LAINNYA ---

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
            'Izin Ditolak',
            'Izin ditolak. Tidak dapat melanjutkan.',
            isError: true,
          );
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
              'Untuk mengimpor/mengekspor file Excel, aplikasi membutuhkan izin penyimpanan. Harap izinkan secara manually di Pengaturan Aplikasi.');
          return false;
        } else {
          if (!context.mounted) return false;
          _showNotification(
            'Izin Ditolak',
            'Izin ditolak. Tidak dapat melanjutkan.',
            isError: true,
          );
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
          'Izin Ditolak',
          'Izin ditolak. Tidak dapat melanjutkan.',
          isError: true,
        );
        return false;
      }
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      log('Platform desktop, assuming file access is granted.');
      return true;
    }
    _showNotification(
      'Platform Tidak Didukung',
      'Platform ini tidak didukung untuk operasi file.',
      isError: true,
    );
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

  Future<void> _exportLogsToExcel(BuildContext context) async {
    setState(() {
      _isLoadingExport = true;
    });

    try {
      var excel = excel_lib.Excel.createExcel();
      String defaultSheetName = excel.getDefaultSheet()!;
      excel_lib.Sheet sheetObject = excel.sheets[defaultSheetName]!;

      for (int i = sheetObject.maxRows - 1; i >= 0; i--) {
        sheetObject.removeRow(i);
      }

      sheetObject.appendRow([
        excel_lib.TextCellValue('Tipe Log'),
        excel_lib.TextCellValue('Nama Barang'),
        excel_lib.TextCellValue('Klasifikasi'),
        excel_lib.TextCellValue('Kuantitas/Remarks'),
        excel_lib.TextCellValue('Tanggal & Waktu'),
        excel_lib.TextCellValue('Nama Staff'),
        excel_lib.TextCellValue('Departemen'),
        excel_lib.TextCellValue('Remarks Tambahan'),
        excel_lib.TextCellValue('Sisa Stok'),
      ]);

      QuerySnapshot snapshot = await _firestore
          .collection('log_entries')
          .orderBy('timestamp', descending: true)
          .get();

      List<LogEntry> allLogs = snapshot.docs.map((doc) {
        return LogEntry.fromFirestore(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      List<LogEntry> filteredLogs =
          allLogs.where(_applyFilters).toList(); // Gunakan _applyFilters

      for (var logEntry in filteredLogs) {
        // --- LOGIC BARU UNTUK MENENTUKAN TIPE LOG (SAMA DENGAN DISPLAY LOGIC) ---
        bool isRemarkAddition =
            logEntry.quantityOrRemark is String && logEntry.remainingStock == 1;
        bool isQuantityAddition =
            logEntry.quantityOrRemark is int && logEntry.quantityOrRemark > 0;

        String logType;
        if (isRemarkAddition || isQuantityAddition) {
          logType = 'Penambahan';
        } else {
          // Termasuk Pengambilan Kuantitas, Pengambilan Remarks, dan Zeroing (remainingStock=0)
          logType = 'Pengambilan';
        }
        // -------------------------------------------------------------------------

        String formattedDateTime =
            '${logEntry.timestamp.day.toString().padLeft(2, '0')}-'
            '${logEntry.timestamp.month.toString().padLeft(2, '0')}-'
            '${logEntry.timestamp.year} '
            '${logEntry.timestamp.hour.toString().padLeft(2, '0')}:'
            '${logEntry.timestamp.minute.toString().padLeft(2, '0')}:'
            '${logEntry.timestamp.second.toString().padLeft(2, '0')}';

        sheetObject.appendRow([
          excel_lib.TextCellValue(logType),
          excel_lib.TextCellValue(logEntry.itemName),
          excel_lib.TextCellValue(logEntry.itemClassification ?? ''),
          excel_lib.TextCellValue(logEntry.quantityOrRemark.toString()),
          excel_lib.TextCellValue(formattedDateTime),
          excel_lib.TextCellValue(logEntry.staffName),
          excel_lib.TextCellValue(logEntry.staffDepartment),
          excel_lib.TextCellValue(logEntry.remarks ?? ''),
          excel_lib.TextCellValue(logEntry.remainingStock?.toString() ?? '-'),
        ]);
      }

      if (defaultSheetName != 'Log Inventaris') {
        excel.rename(defaultSheetName, 'Log Inventaris');
        log('Sheet "$defaultSheetName" berhasil diubah namanya menjadi "Log Inventaris".');
      }

      List<int>? fileBytes = excel.save();
      if (fileBytes != null) {
        final String fileName =
            'Log_Inventaris_QR_Aid_${DateTime.now().millisecondsSinceEpoch}.xlsx';

        if (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux) {
          // Desktop: Save file
          final String? resultPath = await FilePicker.platform.saveFile(
            fileName: fileName,
            type: FileType.custom,
            allowedExtensions: ['xlsx'],
          );

          if (!context.mounted) return;

          if (resultPath != null) {
            final File file = File(resultPath);
            await file.writeAsBytes(fileBytes);
            _showNotification(
                'Ekspor Berhasil', 'Data berhasil diekspor ke: $resultPath',
                isError: false);
            log('File Excel berhasil diekspor ke: $resultPath');
          } else {
            _showNotification(
                'Ekspor Dibatalkan', 'Ekspor dibatalkan oleh pengguna.',
                isError: true);
          }
        } else {
          // Mobile: Share file
          final directory = await getApplicationDocumentsDirectory();
          final filePath = '${directory.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(fileBytes, flush: true);

          await Share.shareXFiles([XFile(filePath)],
              text: 'Data log Strata Lite');

          if (!context.mounted) return;
          _showNotification('Ekspor Berhasil',
              'Data berhasil diekspor ke aplikasi pengelola file.',
              isError: false);
          log('File Excel berhasil diekspor dan akan dibagikan: $filePath');
        }
      } else {
        if (!context.mounted) return;
        _showNotification('Ekspor Gagal', 'Gagal membuat file Excel.',
            isError: true);
      }
    } catch (e) {
      if (!context.mounted) return;
      _showNotification('Ekspor Gagal', 'Error saat ekspor log: $e',
          isError: true);
      log('Error saat ekspor log: $e');
    } finally {
      setState(() {
        _isLoadingExport = false;
      });
    }
  }

  Future<void> _clearLogsByDateRange() async {
    DateTime? startDateToDelete;
    DateTime? endDateToDelete;

    startDateToDelete = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Pilih Tanggal Mulai Hapus Log',
    );
    if (!context.mounted || startDateToDelete == null) return;

    endDateToDelete = await showDatePicker(
      context: context,
      initialDate: startDateToDelete,
      firstDate: startDateToDelete,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Pilih Tanggal Akhir Hapus Log',
    );
    if (!context.mounted || endDateToDelete == null) return;

    if (startDateToDelete.isAfter(endDateToDelete)) {
      _showNotification('Tanggal Invalid',
          'Tanggal mulai tidak boleh lebih dari tanggal akhir.',
          isError: true);
      return;
    }

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus Log'),
        content: Text(
            'Anda yakin ingin menghapus semua log dari ${DateFormat('dd-MM-yyyy').format(startDateToDelete!)} sampai ${DateFormat('dd-MM-yyyy').format(endDateToDelete!)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (!context.mounted || confirm != true) return;

    setState(() {
      _isLoadingDelete = true;
    });

    try {
      QuerySnapshot logsToDelete = await _firestore
          .collection('log_entries')
          .where('timestamp',
              isGreaterThanOrEqualTo: DateTime(startDateToDelete.year,
                  startDateToDelete.month, startDateToDelete.day))
          .where('timestamp',
              isLessThanOrEqualTo: DateTime(endDateToDelete.year,
                  endDateToDelete.month, endDateToDelete.day, 23, 59, 59, 999))
          .get();

      WriteBatch batch = _firestore.batch();
      for (var doc in logsToDelete.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      _showNotification('Berhasil Dihapus',
          '${logsToDelete.docs.length} log berhasil dihapus.',
          isError: false);
      log('Deleted ${logsToDelete.docs.length} log entries from ${DateFormat('dd-MM-yyyy').format(startDateToDelete)} to ${DateFormat('dd-MM-yyyy').format(endDateToDelete)}');
    } catch (e) {
      _showNotification('Gagal Menghapus Log', 'Error menghapus log: $e',
          isError: true);
      log('Error deleting logs: $e');
    } finally {
      setState(() {
        _isLoadingDelete = false;
      });
    }
  }

  // --- FUNGSI BARU UNTUK APLIKASI FILTER DI LOGIC ---
  bool _applyFilters(LogEntry logEntry) {
    // 1. Filter Pencarian
    final String lowerCaseQuery = _searchQuery.toLowerCase();
    bool matchesSearch = logEntry.itemName
            .toLowerCase()
            .contains(lowerCaseQuery) ||
        logEntry.staffName.toLowerCase().contains(lowerCaseQuery) ||
        logEntry.staffDepartment.toLowerCase().contains(lowerCaseQuery) ||
        (logEntry.itemClassification?.toLowerCase().contains(lowerCaseQuery) ??
            false) ||
        (logEntry.remarks?.toLowerCase().contains(lowerCaseQuery) ?? false);

    if (!matchesSearch) return false;

    // 2. Filter Tanggal
    if (_selectedStartDate != null && _selectedEndDate != null) {
      final logDate = DateTime(logEntry.timestamp.year,
          logEntry.timestamp.month, logEntry.timestamp.day);
      final startDate = DateTime(_selectedStartDate!.year,
          _selectedStartDate!.month, _selectedStartDate!.day);
      final endDate = DateTime(_selectedEndDate!.year, _selectedEndDate!.month,
          _selectedEndDate!.day);

      // Filter harus mencakup hari akhir (hingga 23:59:59)
      if (logDate.isBefore(startDate) || logDate.isAfter(endDate)) {
        return false;
      }
    }

    // 3. Filter Waktu
    if (_selectedStartTime != null && _selectedEndTime != null) {
      final logMinutes =
          logEntry.timestamp.hour * 60 + logEntry.timestamp.minute;
      final startMinutes =
          _selectedStartTime!.hour * 60 + _selectedStartTime!.minute;
      final endMinutes = _selectedEndTime!.hour * 60 + _selectedEndTime!.minute;

      // Ini adalah filtering yang disederhanakan, tidak menangani wrap-around tengah malam dengan sempurna
      // Tetapi berfungsi jika rentang waktu tidak melintasi tengah malam.
      if (logMinutes < startMinutes || logMinutes > endMinutes) {
        return false;
      }
    }

    // 4. Filter Klasifikasi
    if (_selectedClassification != 'Semua Klasifikasi' &&
        logEntry.itemClassification != _selectedClassification) {
      return false;
    }

    // 5. Filter Tipe Transaksi (Logic yang Diperbarui)
    if (_selectedTransactionType != 'Semua') {
      // Tentukan apakah ini log Penambahan (Quantity > 0 ATAU Remarks Update Marker == 1)
      bool isRemarkAddition =
          logEntry.quantityOrRemark is String && logEntry.remainingStock == 1;
      bool isQuantityAddition =
          logEntry.quantityOrRemark is int && logEntry.quantityOrRemark > 0;

      bool isAdding = isRemarkAddition || isQuantityAddition;

      // Sisanya (Quantity < 0, Remarks Log tanpa marker) adalah Pengambilan
      bool isTaking = !isAdding;

      if (_selectedTransactionType == 'Penambahan' && !isAdding) {
        return false;
      }
      if (_selectedTransactionType == 'Pengambilan' && !isTaking) {
        return false;
      }
    }

    return true;
  }
  // --- END FUNGSI BARU ---

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = _firestore.collection('log_entries');

    // Filter Firestore hanya berdasarkan tanggal dan klasifikasi, karena filter waktu dan tipe transaksi harus diterapkan di sisi klien
    if (_selectedStartDate != null) {
      DateTime startOfDay = DateTime(_selectedStartDate!.year,
          _selectedStartDate!.month, _selectedStartDate!.day);
      query = query.where('timestamp', isGreaterThanOrEqualTo: startOfDay);
    }
    if (_selectedEndDate != null) {
      DateTime endOfDay = DateTime(_selectedEndDate!.year,
          _selectedEndDate!.month, _selectedEndDate!.day, 23, 59, 59, 999);
      query = query.where('timestamp', isLessThanOrEqualTo: endOfDay);
    }

    if (_selectedClassification != null &&
        _selectedClassification != 'Semua Klasifikasi') {
      query =
          query.where('itemClassification', isEqualTo: _selectedClassification);
    }

    query = query.orderBy('timestamp', descending: true);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            // 1. Pinned Search Bar & Filter Toggle
            SliverAppBar(
              automaticallyImplyLeading: false,
              pinned: true,
              floating: true,
              snap: true,
              title: const Text('Riwayat Transaksi'), // Title
              bottom: PreferredSize(
                // KOREKSI: Menggunakan 57.0 untuk mencegah overflow 1.0 piksel
                preferredSize: const Size.fromHeight(57.0),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Cari nama barang, staff, dll...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30.0),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 0, horizontal: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: Icon(
                            _showFilters
                                ? Icons.filter_alt_off
                                : Icons.filter_alt,
                            color: Theme.of(context).primaryColor),
                        onPressed: _toggleFilters,
                        tooltip: _showFilters
                            ? 'Sembunyikan Filter Lanjutan'
                            : 'Tampilkan Filter Lanjutan',
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Collapsible Filter Card
            if (_showFilters)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Filter Lanjutan:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.blueAccent)),
                          const Divider(height: 15, thickness: 1),

                          // --- DATE FILTERS ---
                          _buildFilterTitle('Tanggal Transaksi'),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _selectDate(context, isStartDate: true),
                                  icon: const Icon(Icons.calendar_today),
                                  label: Text(_selectedStartDate == null
                                      ? 'Dari Tanggal'
                                      : DateFormat('dd-MM-yyyy')
                                          .format(_selectedStartDate!)),
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          _selectedStartDate != null
                                              ? Colors.blue[700]
                                              : Colors.grey[700],
                                      side: BorderSide(
                                          color: _selectedStartDate != null
                                              ? Colors.blue[700]!
                                              : Colors.grey[400]!),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _selectDate(context, isStartDate: false),
                                  icon: const Icon(Icons.calendar_today),
                                  label: Text(_selectedEndDate == null
                                      ? 'Sampai Tanggal'
                                      : DateFormat('dd-MM-yyyy')
                                          .format(_selectedEndDate!)),
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: _selectedEndDate != null
                                          ? Colors.blue[700]
                                          : Colors.grey[700],
                                      side: BorderSide(
                                          color: _selectedEndDate != null
                                              ? Colors.blue[700]!
                                              : Colors.grey[400]!),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),

                          // --- TIME FILTERS ---
                          _buildFilterTitle('Waktu Transaksi'),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _selectTime(context, isStartTime: true),
                                  icon: const Icon(Icons.access_time),
                                  label: Text(_selectedStartTime == null
                                      ? 'Dari Jam'
                                      : _selectedStartTime!.format(context)),
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          _selectedStartTime != null
                                              ? Colors.blue[700]
                                              : Colors.grey[700],
                                      side: BorderSide(
                                          color: _selectedStartTime != null
                                              ? Colors.blue[700]!
                                              : Colors.grey[400]!),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _selectTime(context, isStartTime: false),
                                  icon: const Icon(Icons.access_time),
                                  label: Text(_selectedEndTime == null
                                      ? 'Sampai Jam'
                                      : _selectedEndTime!.format(context)),
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: _selectedEndTime != null
                                          ? Colors.blue[700]
                                          : Colors.grey[700],
                                      side: BorderSide(
                                          color: _selectedEndTime != null
                                              ? Colors.blue[700]!
                                              : Colors.grey[400]!),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),

                          // --- CLASSIFICATION FILTER ---
                          _buildFilterTitle('Klasifikasi Barang'),
                          DropdownButtonFormField<String>(
                            value: _selectedClassification,
                            decoration: InputDecoration(
                              labelText: 'Pilih Klasifikasi',
                              border: const OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(8))),
                              prefixIcon: const Icon(Icons.category),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                            ),
                            items: _dynamicClassifications
                                .map((String classification) {
                              return DropdownMenuItem<String>(
                                value: classification,
                                child: Text(classification),
                              );
                            }).toList(),
                            onChanged: _isClassificationsLoading
                                ? null
                                : (String? newValue) {
                                    setState(() {
                                      _selectedClassification = newValue;
                                    });
                                  },
                          ),

                          // --- TRANSACTION TYPE FILTER ---
                          const SizedBox(height: 15),
                          _buildFilterTitle('Tipe Transaksi'),
                          DropdownButtonFormField<String>(
                            value: _selectedTransactionType,
                            decoration: InputDecoration(
                              labelText: 'Pilih Tipe Transaksi',
                              border: const OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(8))),
                              prefixIcon: const Icon(Icons.swap_vert),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                            ),
                            items: ['Semua', 'Penambahan', 'Pengambilan']
                                .map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedTransactionType = newValue;
                                });
                              }
                            },
                          ),

                          if (_isClassificationsLoading)
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: LinearProgressIndicator(),
                            ),

                          // --- RESET BUTTON (DIPINDAH KE DALAM CARD) ---
                          const SizedBox(height: 20),
                          ElevatedButton(
                              onPressed: _clearFilters,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12)),
                              child: const Center(child: Text('Reset Filter'))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // 3. Action Buttons (Export/Delete) - Selalu terlihat/scrollable
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: _buildActionButton(
                      label: 'Ekspor Log',
                      icon: Icons.download,
                      isLoading: _isLoadingExport,
                      color: Colors.green,
                      onPressed: () {
                        if (!context.mounted) return;
                        _exportLogsToExcel(context);
                      },
                    )),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildActionButton(
                      label: 'Hapus Log',
                      icon: Icons.delete_forever,
                      isLoading: _isLoadingDelete,
                      color: Colors.red,
                      onPressed: _clearLogsByDateRange,
                    )),
                  ],
                ),
              ),
            ),

            // 4. Log List Title (Header untuk daftar log)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 10.0),
                child: Text(
                  'Riwayat Pengambilan Barang:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ),
          ];
        },

        // Body (Daftar Log)
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              List<LogEntry> allLogs = snapshot.data!.docs.map((doc) {
                return LogEntry.fromFirestore(
                    doc.data() as Map<String, dynamic>, doc.id);
              }).toList();

              // Mengaplikasikan filter sisi klien (waktu, tipe transaksi, dan kueri pencarian tambahan)
              List<LogEntry> filteredLogs =
                  allLogs.where(_applyFilters).toList();

              if (filteredLogs.isEmpty) {
                bool isAnyFilterActive = _searchQuery.isNotEmpty ||
                    _selectedStartDate != null ||
                    _selectedEndDate != null ||
                    _selectedTransactionType != 'Semua' ||
                    (_selectedClassification != null &&
                        _selectedClassification != 'Semua Klasifikasi');

                if (isAnyFilterActive) {
                  return const Center(
                    child: Text(
                      'Tidak ada log yang ditemukan dengan kriteria pencarian ini.',
                    ),
                  );
                } else {
                  return const Center(
                    child: Text(
                      'Belum ada riwayat pengambilan barang.',
                    ),
                  );
                }
              }

              // List View yang menampilkan kartu log yang lebih rapi
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 16.0),
                itemCount: filteredLogs.length,
                itemBuilder: (context, index) {
                  final logEntry = filteredLogs[index];
                  String formattedDateTime =
                      '${DateFormat('dd-MM-yyyy').format(logEntry.timestamp)} '
                      '${DateFormat('HH:mm:ss').format(logEntry.timestamp)}';

                  // --- LOGIC BARU UNTUK TAMPILAN ---
                  bool isRemarkAddition = logEntry.quantityOrRemark is String &&
                      logEntry.remainingStock == 1;
                  bool isQuantityAddition = logEntry.quantityOrRemark is int &&
                      logEntry.quantityOrRemark > 0;
                  bool isAdding = isRemarkAddition || isQuantityAddition;

                  Color logColor = isAdding ? Colors.green : Colors.red;

                  // Tentukan logTitle
                  String logTitle;
                  if (isRemarkAddition) {
                    logTitle = 'Pembaruan Status (Penambahan)';
                    logColor = Colors
                        .green; // Pastikan warnanya hijau untuk penambahan status
                  } else if (isQuantityAddition) {
                    logTitle = 'Penambahan Kuantitas';
                  } else {
                    logTitle = 'Pengambilan';
                  }

                  IconData logIcon =
                      isAdding ? Icons.add_circle : Icons.remove_circle;
                  // ------------------------------------

                  String quantityText;
                  if (logEntry.quantityOrRemark is int) {
                    quantityText = logEntry.quantityOrRemark.abs().toString();
                  } else {
                    quantityText = logEntry.quantityOrRemark.toString();
                  }

                  // Logika Tampilan Stok
                  String stockTextBefore = 'N/A';
                  String stockTextAfter = 'N/A';
                  Color stockColor = Colors.blueGrey;

                  if (logEntry.remainingStock != null &&
                      logEntry.quantityOrRemark is int) {
                    // Logika untuk item berbasis kuantitas
                    int stockAfter = logEntry.remainingStock as int;
                    int quantityChange = logEntry.quantityOrRemark as int;
                    int stockBefore = stockAfter - quantityChange;
                    stockTextBefore = stockBefore.toString();
                    stockTextAfter = stockAfter.toString();
                    stockColor =
                        (stockAfter == 0) ? Colors.red : Colors.green[800]!;
                  }

                  String classificationText =
                      logEntry.itemClassification != null &&
                              logEntry.itemClassification!.isNotEmpty
                          ? logEntry.itemClassification!
                          : 'Tidak Ada';

                  // --- DESAIN KARTU LOG BARU ---
                  return Card(
                    margin: const EdgeInsets.only(bottom: 15.0),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(
                          color: logColor.withOpacity(0.5), width: 1.5),
                    ),
                    color: Colors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16.0),
                      leading: CircleAvatar(
                        backgroundColor: logColor.withOpacity(0.1),
                        child: Icon(logIcon, color: logColor, size: 28),
                      ),
                      title: Text(
                        logEntry.itemName,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Theme.of(context).primaryColor),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          // Menampilkan Log Title yang sudah disesuaikan
                          Text('Tipe Log: $logTitle',
                              style: TextStyle(
                                  color: logColor,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          _buildLogDetailRow(Icons.category, 'Klasifikasi',
                              classificationText),
                          _buildLogDetailRow(
                              Icons.access_time, 'Waktu', formattedDateTime),

                          // Menampilkan Staff dan Departemen
                          _buildLogDetailRow(Icons.person, 'Staff',
                              '${logEntry.staffName} (${logEntry.staffDepartment})'),

                          // Detail Kuantitas / Remarks
                          const SizedBox(height: 8),
                          _buildLogDetailRow(
                              logEntry.quantityOrRemark is String
                                  ? Icons.notes
                                  : Icons.production_quantity_limits,
                              // KOREKSI LABEL: Jika Pembaruan Status, labelnya adalah 'Keterangan Item'
                              (logEntry.quantityOrRemark is String)
                                  ? 'Keterangan Item'
                                  : 'Kuantitas',
                              quantityText,
                              isBoldValue: true),

                          // Stok Sebelum dan Sesudah
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: [
                                const Icon(Icons.inventory_2,
                                    size: 18, color: Colors.blueGrey),
                                const SizedBox(width: 8),
                                Text(
                                  // KOREKSI TAMPILAN STOK: Jika log update remarks atau remarks log biasa, tampilkan N/A
                                  'Stok: ${logEntry.quantityOrRemark is String ? 'N/A' : '$stockTextBefore -> $stockTextAfter'}',
                                  style: TextStyle(
                                      fontSize: 15,
                                      color: stockColor,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),

                          // Remarks Tambahan (hanya untuk log stok yang bukan update remarks)
                          if (logEntry.remarks != null &&
                              logEntry.remarks!.isNotEmpty &&
                              !isRemarkAddition) // Jangan tampilkan remarks lagi jika sudah menjadi Keterangan Item
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: _buildLogDetailRow(Icons.info_outline,
                                  'Catatan', logEntry.remarks!,
                                  isItalic: true),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // Helper widget untuk baris detail log
  Widget _buildLogDetailRow(IconData icon, String label, String value,
      {bool isBoldValue = false, bool isItalic = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              // Penggunaan konstruktor TextSpan dari Flutter
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(fontSize: 14, color: Colors.blueGrey[700]),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight:
                          isBoldValue ? FontWeight.bold : FontWeight.normal,
                      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
