import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';
import 'package:another_flushbar/flushbar.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoadingExport = false;

  Timer? _notificationTimer;
  final List<String> _departments = [
    'A&G',
    'ENGINEERING',
    'FB PRODUCT',
    'FB SERVICE',
    'FINANCE',
    'FRONT OFFICE',
    'HOUSEKEEPING',
    'HR',
    'IT',
    'Marketing',
    'SALES',
    'SALES & MARKETING',
    'Security',
  ];
  final List<String> _roles = ['staff'];

  static const String _fictitiousDomain = '@strata.com';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
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

  Future<void> _addEditUser({DocumentSnapshot? userToEdit}) async {
    final bool isEditing = userToEdit != null;
    final formKey = GlobalKey<FormState>();

    TextEditingController nameController = TextEditingController(
        text: isEditing
            ? (userToEdit!.data() as Map<String, dynamic>)['name']
            : '');
    TextEditingController usernameController = TextEditingController(
        text: isEditing
            ? (userToEdit!.data() as Map<String, dynamic>)['email']
                .toString()
                .split('@')[0]
            : '');
    TextEditingController newPasswordController = TextEditingController();
    TextEditingController adminPasswordController = TextEditingController();

    String? selectedDepartment = isEditing
        ? (userToEdit!.data() as Map<String, dynamic>)['department']
        : _departments.first;
    String? selectedRole = isEditing
        ? (userToEdit!.data() as Map<String, dynamic>)['role']
        : _roles.first;

    bool _obscureNewPassword = true;
    bool _obscureAdminPassword = true;

    if (!isEditing && !_departments.contains(selectedDepartment)) {
      selectedDepartment = _departments.first;
    }
    if (!isEditing && !_roles.contains(selectedRole)) {
      selectedRole = _roles.first;
    }

    String? adminEmail = _auth.currentUser?.email;
    if (adminEmail == null) {
      _showNotification(
          'Error', 'Sesi admin tidak ditemukan. Silakan login ulang.',
          isError: true);
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: Text(isEditing ? 'Edit Pengguna' : 'Tambah Pengguna Baru'),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lengkap',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Nama tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        border: const OutlineInputBorder(),
                        suffixText: isEditing ? null : _fictitiousDomain,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      readOnly: isEditing,
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Username tidak boleh kosong';
                        }
                        if (!isEditing && value.contains('@')) {
                          return 'Username tidak boleh mengandung "@"';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedDepartment,
                      decoration: const InputDecoration(
                        labelText: 'Departemen',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _departments
                          .map((dep) =>
                              DropdownMenuItem(value: dep, child: Text(dep)))
                          .toList(),
                      onChanged: (value) => setStateSB(() {
                        selectedDepartment = value;
                      }),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Pilih departemen'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      items: _roles
                          .map((role) => DropdownMenuItem(
                              value: role, child: Text(role.toUpperCase())))
                          .toList(),
                      onChanged: (value) => setStateSB(() {
                        selectedRole = value;
                      }),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Pilih role' : null,
                    ),
                    const SizedBox(height: 10),
                    if (!isEditing) ...[
                      TextFormField(
                        controller: newPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Password Pengguna Baru (min. 6 karakter)',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setStateSB(() {
                                _obscureNewPassword = !_obscureNewPassword;
                              });
                            },
                          ),
                        ),
                        obscureText: _obscureNewPassword,
                        validator: (value) => value!.length < 6
                            ? 'Password minimal 6 karakter'
                            : null,
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextFormField(
                      controller: adminPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Sandi Admin Anda',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureAdminPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setStateSB(() {
                              _obscureAdminPassword = !_obscureAdminPassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscureAdminPassword,
                      validator: (value) => value!.isEmpty
                          ? 'Sandi admin tidak boleh kosong.'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }

                  final localDialogContext = dialogContext;
                  final String? currentAdminEmail = _auth.currentUser!.email;
                  final String currentAdminPassword =
                      adminPasswordController.text.trim();
                  final String userEmail = isEditing
                      ? (userToEdit!.data() as Map<String, dynamic>)['email']
                      : usernameController.text.trim() + _fictitiousDomain;
                  final String newPassword = newPasswordController.text.trim();

                  Navigator.of(localDialogContext).pop();

                  try {
                    // Otentikasi ulang admin (sebenarnya tidak perlu karena sudah login)
                    await _auth.signInWithEmailAndPassword(
                        email: currentAdminEmail!,
                        password: currentAdminPassword);

                    if (isEditing) {
                      // Perbarui data Firestore
                      await _firestore
                          .collection('users')
                          .doc(userToEdit!.id)
                          .update({
                        'name': nameController.text.trim(),
                        'department': selectedDepartment,
                        'role': selectedRole,
                      });
                      _showNotification('Berhasil!',
                          'Pengguna ${nameController.text} berhasil diperbarui.',
                          isError: false);
                    } else {
                      // Logika untuk menambahkan pengguna baru
                      final newUserCredential =
                          await _auth.createUserWithEmailAndPassword(
                              email: userEmail, password: newPassword);

                      // --- Penambahan kode untuk mengatasi masalah sesi ---
                      // Masuk kembali sebagai admin setelah membuat pengguna baru
                      await _auth.signInWithEmailAndPassword(
                          email: currentAdminEmail!,
                          password: currentAdminPassword);
                      // ---------------------------------------------------

                      await _firestore
                          .collection('users')
                          .doc(newUserCredential.user!.uid)
                          .set({
                        'name': nameController.text.trim(),
                        'email': userEmail,
                        'department': selectedDepartment,
                        'role': selectedRole,
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      _showNotification('Akun Berhasil Dibuat!',
                          'Pengguna ${nameController.text} berhasil ditambahkan.',
                          isError: false);
                    }
                  } on FirebaseAuthException catch (e) {
                    String message;
                    if (e.code == 'wrong-password' ||
                        e.code == 'invalid-credential') {
                      message = 'Sandi admin salah.';
                    } else if (e.code == 'email-already-in-use') {
                      message = 'Username ini sudah terdaftar.';
                    } else if (e.code == 'weak-password') {
                      message = 'Password terlalu lemah.';
                    } else {
                      message = 'Gagal memproses akun: ${e.message}';
                    }
                    _showNotification('Gagal!', message, isError: true);
                  } catch (e) {
                    _showNotification('Error', 'Terjadi kesalahan umum: $e',
                        isError: true);
                    log('Error in add/edit user flow: $e');
                  }
                },
                child: Text(isEditing ? 'Simpan Perubahan' : 'Tambah Pengguna'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteUser(String userId, String userName) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        _showNotification('Gagal!', 'Pengguna tidak ditemukan.', isError: true);
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      if (userData['role'] == 'admin') {
        _showNotification('Gagal Menghapus',
            'Tidak dapat menghapus pengguna dengan peran admin.',
            isError: true);
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Konfirmasi Hapus'),
          content:
              Text('Apakah Anda yakin ingin menghapus pengguna $userName?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _firestore.collection('users').doc(userId).delete();
        _showNotification('Berhasil!', 'Pengguna $userName berhasil dihapus.',
            isError: false);
      }
    } catch (e) {
      _showNotification('Gagal!', 'Terjadi kesalahan saat menghapus pengguna.',
          isError: true);
      log('Error deleting user: $e');
    }
  }

  Future<void> _exportUsersToExcel() async {
    setState(() {
      _isLoadingExport = true;
    });

    await _handleStoragePermission(() async {
      try {
        final querySnapshot = await _firestore.collection('users').get();
        final usersData = querySnapshot.docs;

        if (usersData.isEmpty) {
          _showNotification('Info', 'Tidak ada pengguna untuk diekspor.',
              isError: false);
          return;
        }

        final excel = Excel.createExcel();
        final defaultSheetName = excel.getDefaultSheet()!;
        excel.rename(defaultSheetName, 'Daftar Pengguna');
        final sheet = excel['Daftar Pengguna'];

        List<String> headers = [
          'Nama Lengkap',
          'Username',
          'Email Lengkap',
          'Nomor Telepon',
          'Departemen',
          'Role'
        ];
        sheet.insertRowIterables(
            headers.map((e) => TextCellValue(e)).toList(), 0);

        for (int i = 0; i < usersData.length; i++) {
          final userData = usersData[i].data() as Map<String, dynamic>;
          String phoneNumber = userData['phoneNumber']?.toString() ?? '';
          String email = userData['email'] ?? '';
          String username = email.split('@')[0];

          if (phoneNumber.startsWith('0')) {
            phoneNumber = "'$phoneNumber";
          }

          List<dynamic> row = [
            userData['name'] ?? '',
            username,
            email,
            phoneNumber,
            userData['department'] ?? '',
            userData['role'] ?? '',
          ];
          sheet.insertRowIterables(
              row.map((e) => TextCellValue(e.toString())).toList(), i + 1);
        }

        final excelBytes = excel.encode()!;
        if (excelBytes == null || excelBytes.isEmpty) {
          _showNotification('Ekspor Gagal', 'Gagal membuat file Excel.',
              isError: true);
          return;
        }

        final String fileName =
            'Daftar_Pengguna_Strata_${DateTime.now().millisecondsSinceEpoch}.xlsx';

        if (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux) {
          // Logic for desktop platforms
          final String? resultPath = await FilePicker.platform.saveFile(
            fileName: fileName,
            type: FileType.custom,
            allowedExtensions: ['xlsx'],
          );

          if (!mounted) return;

          if (resultPath != null) {
            final File file = File(resultPath);
            await file.writeAsBytes(excelBytes);
            _showNotification('Berhasil!',
                'Daftar pengguna berhasil diekspor ke Excel di: $resultPath',
                isError: false);
          } else {
            _showNotification('Ekspor Dibatalkan',
                'Ekspor dibatalkan atau file tidak disimpan.',
                isError: true);
          }
        } else {
          // Logic for mobile platforms (Android & iOS)
          final directory = await getApplicationDocumentsDirectory();
          final filePath = '${directory.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(excelBytes, flush: true);

          await Share.shareXFiles([XFile(filePath)],
              text: 'Daftar pengguna Strata Lite');

          if (!mounted) return;
          _showNotification('Ekspor Berhasil',
              'Data berhasil diekspor. Pilih aplikasi untuk menyimpan file.',
              isError: false);
        }
      } catch (e) {
        _showNotification(
            'Gagal Export', 'Terjadi kesalahan saat mengekspor data: $e',
            isError: true);
        log('Error exporting users: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoadingExport = false;
          });
        }
      }
    });
  }

  Future<void> _importUsersFromExcel() async {
    await _handleStoragePermission(() async {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );
        log('DEBUG: FilePicker result: $result');

        if (result == null || result.files.single.path == null) {
          _showNotification(
              'Impor Dibatalkan', 'Tidak ada file yang dipilih untuk diimpor.',
              isError: true);
          return;
        }

        File file = File(result.files.single.path!);
        var bytes = file.readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        int importedCount = 0;
        int failedCount = 0;

        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table];
          if (sheet == null || sheet.rows.isEmpty) continue;

          final headerRow = sheet.rows.first
              .map((cell) => cell?.value?.toString().trim())
              .toList();

          final nameIndex = headerRow.indexOf('Nama Lengkap');
          final usernameIndex = headerRow.indexOf('Username');
          final phoneIndex = headerRow.indexOf('Nomor Telepon');
          final departmentIndex = headerRow.indexOf('Departemen');
          final roleIndex = headerRow.indexOf('Role');
          final passwordIndex = headerRow.indexOf('Password');

          if (nameIndex == -1 ||
              usernameIndex == -1 ||
              departmentIndex == -1 ||
              roleIndex == -1 ||
              passwordIndex == -1) {
            _showNotification('Gagal Import',
                'File Excel tidak memiliki semua kolom yang diperlukan (Nama Lengkap, Username, Nomor Telepon, Departemen, Role, Password).',
                isError: true);
            return;
          }

          String? adminPassword = await _showAdminPasswordDialog();
          if (adminPassword == null) {
            _showNotification(
                'Impor Dibatalkan', 'Sandi admin tidak dimasukkan.',
                isError: true);
            return;
          }
          final currentAdminEmail = _auth.currentUser!.email;

          for (int i = 1; i < sheet.rows.length; i++) {
            final row = sheet.rows[i];
            final String name =
                (row[nameIndex]?.value?.toString().trim() ?? '');
            final String username =
                (row[usernameIndex]?.value?.toString().trim() ?? '');
            final String email = username + _fictitiousDomain;
            final String phoneNumber =
                (row[phoneIndex]?.value?.toString().trim() ?? '');
            String role = (row[roleIndex]?.value?.toString().trim() ?? 'staff')
                .toLowerCase();
            final String password =
                (row[passwordIndex]?.value?.toString().trim() ?? '');
            final String department =
                (row[departmentIndex]?.value?.toString().trim() ?? '');

            if (name.isEmpty || username.isEmpty || password.isEmpty) {
              log('Skipping row $i: Nama, Username, atau Password kosong.');
              failedCount++;
              continue;
            }
            if (password.length < 6) {
              log('Skipping row $i: Password kurang dari 6 karakter.');
              failedCount++;
              continue;
            }

            if (!_roles.contains(role)) {
              role = 'staff';
            }
            if (!_departments.contains(department)) {
              log('Skipping row $i: Departemen tidak valid.');
              failedCount++;
              continue;
            }

            try {
              // Re-authenticate the admin before creating new users.
              await _auth.signInWithEmailAndPassword(
                  email: currentAdminEmail!, password: adminPassword);

              final newUserCredential =
                  await _auth.createUserWithEmailAndPassword(
                      email: email, password: password);

              // Masuk kembali sebagai admin setelah membuat pengguna baru
              await _auth.signInWithEmailAndPassword(
                  email: currentAdminEmail, password: adminPassword);

              await _firestore
                  .collection('users')
                  .doc(newUserCredential.user!.uid)
                  .set({
                'name': name,
                'email': email,
                'phoneNumber': phoneNumber,
                'department': department,
                'role': role,
                'createdAt': FieldValue.serverTimestamp(),
              });
              importedCount++;
            } on FirebaseAuthException catch (e) {
              log('Gagal mengimpor $email (Auth Error): ${e.message}');
              failedCount++;
            } catch (e) {
              log('Gagal mengimpor $email (General Error): $e');
              failedCount++;
            }
          }
        }

        String importSummaryMessage =
            '$importedCount pengguna berhasil diimpor. $failedCount pengguna gagal diimpor.';

        _showNotification(
          'Impor Selesai!',
          importSummaryMessage,
          isError: failedCount > 0,
        );
      } catch (e) {
        _showNotification(
            'Gagal Import', 'Terjadi kesalahan saat mengimpor file Excel: $e',
            isError: true);
        log('Error importing users: $e');
      }
    });
  }

  Future<void> _downloadImportTemplate() async {
    await _handleStoragePermission(() async {
      try {
        final excel = Excel.createExcel();
        final defaultSheetName = excel.getDefaultSheet()!;
        excel.rename(defaultSheetName, 'Template Import Pengguna');
        final sheet = excel['Template Import Pengguna'];

        List<String> headers = [
          'Nama Lengkap',
          'Username',
          'Nomor Telepon',
          'Departemen',
          'Role',
          'Password'
        ];
        sheet.insertRowIterables(
            headers.map((e) => TextCellValue(e)).toList(), 0);

        final excelBytes = excel.encode()!;
        log('DEBUG: Data Excel berhasil dibuat.');

        final String fileName =
            'Template_Import_Pengguna_Strata_${DateTime.now().millisecondsSinceEpoch}.xlsx';

        if (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux) {
          final String? resultPath = await FilePicker.platform.saveFile(
            fileName: fileName,
            type: FileType.custom,
            allowedExtensions: ['xlsx'],
          );

          if (!mounted) return;

          if (resultPath != null) {
            final File file = File(resultPath);
            await file.writeAsBytes(excelBytes);
            _showNotification('Berhasil!',
                'Template impor Excel berhasil diunduh ke: $resultPath',
                isError: false);
            log('File template berhasil diunduh ke: $resultPath');
          } else {
            _showNotification('Pengunduhan Dibatalkan',
                'Pengunduhan template dibatalkan atau file tidak disimpan.',
                isError: true);
          }
        } else {
          final directory = await getApplicationDocumentsDirectory();
          final filePath = '${directory.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(excelBytes, flush: true);

          await Share.shareXFiles([XFile(filePath)],
              text: 'Template Import Pengguna Strata Lite');

          if (!mounted) return;
          _showNotification('Berhasil!',
              'Template berhasil dibuat. Pilih aplikasi untuk menyimpannya.',
              isError: false);
        }
      } catch (e) {
        _showNotification('Gagal Download Template',
            'Terjadi kesalahan saat mengunduh template: $e',
            isError: true);
        log('Error downloading template: $e');
      }
    });
  }

  Future<void> _handleStoragePermission(Function onPermissionGranted) async {
    log('DEBUG: Memulai proses pengecekan izin penyimpanan.');
    PermissionStatus status;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+
        status = await Permission.photos.request();
      } else {
        // Android < 13
        status = await Permission.storage.request();
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      status = await Permission.photos.request();
    } else {
      // Assume desktop platforms have no permission issues for saving files
      status = PermissionStatus.granted;
    }

    log('DEBUG: Status izin setelah permintaan: $status');

    if (status.isGranted) {
      log('DEBUG: Izin diberikan.');
      onPermissionGranted();
    } else if (status.isPermanentlyDenied) {
      log('DEBUG: Izin ditolak secara permanen. Membuka pengaturan aplikasi.');
      _showNotification(
        'Izin Ditolak Permanen',
        'Aplikasi memerlukan izin penyimpanan untuk melanjutkan. Silakan berikan izin secara manual di Pengaturan.',
        isError: true,
      );
      openAppSettings();
    } else {
      log('DEBUG: Izin Ditolak');
      _showNotification(
        'Izin Ditolak',
        'Tidak dapat melanjutkan tanpa izin penyimpanan. Silakan coba lagi.',
        isError: true,
      );
    }
  }

  Future<String?> _showAdminPasswordDialog() async {
    TextEditingController passwordController = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Konfirmasi Sandi Admin'),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Masukkan sandi admin'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (passwordController.text.isNotEmpty) {
                  Navigator.of(context).pop(passwordController.text);
                }
              },
              child: const Text('Konfirmasi'),
            ),
          ],
        );
      },
    );
  }

  void _showImportExportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Export Pengguna ke Excel'),
                onTap: () {
                  Navigator.pop(bc);
                  _exportUsersToExcel();
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload),
                title: const Text('Import Pengguna dari Excel'),
                onTap: () {
                  Navigator.pop(bc);
                  _importUsersFromExcel();
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_download),
                title: const Text('Download Template Import Excel'),
                onTap: () {
                  Navigator.pop(bc);
                  _downloadImportTemplate();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText:
                      'Cari pengguna (nama, username, departemen, role)...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Daftar Pengguna Terdaftar:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _addEditUser(),
                icon: const Icon(Icons.person_add),
                label: const Text('Tambah Pengguna'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: _showImportExportOptions,
                tooltip: 'Opsi Import/Export',
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('users').orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                    child: Text('Belum ada pengguna terdaftar.'));
              }

              List<DocumentSnapshot> allUsers = snapshot.data!.docs;

              List<DocumentSnapshot> filteredUsers = allUsers.where((userDoc) {
                final data = userDoc.data() as Map<String, dynamic>?;
                if (data == null) return false;

                final String lowerCaseQuery = _searchQuery.toLowerCase();
                final String name = (data['name'] ?? '').toLowerCase();
                final String email = (data['email'] ?? '').toLowerCase();
                final String username = email.split('@')[0];
                final String department =
                    (data['department'] ?? '').toLowerCase();
                final String role = (data['role'] ?? '').toLowerCase();
                final String phoneNumber =
                    (data['phoneNumber'] ?? '').toLowerCase();

                return name.contains(lowerCaseQuery) ||
                    username.contains(lowerCaseQuery) ||
                    email.contains(lowerCaseQuery) ||
                    department.contains(lowerCaseQuery) ||
                    role.contains(lowerCaseQuery) ||
                    phoneNumber.contains(lowerCaseQuery);
              }).toList();

              if (filteredUsers.isEmpty && _searchQuery.isNotEmpty) {
                return const Center(child: Text('Pengguna tidak ditemukan.'));
              }
              if (filteredUsers.isEmpty && _searchQuery.isEmpty) {
                return const Center(
                    child: Text('Belum ada pengguna terdaftar.'));
              }

              return ListView.builder(
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final userDoc = filteredUsers[index];
                  final userData = userDoc.data() as Map<String, dynamic>;

                  final String name = userData['name'] ?? 'N/A';
                  final String email = userData['email'] ?? 'N/A';
                  final String department = userData['department'] ?? 'N/A';
                  final String role = userData['role'] ?? 'N/A';

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      leading: const CircleAvatar(
                        backgroundColor: Colors.blueAccent,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black87),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Email: $email',
                              style: const TextStyle(fontSize: 14)),
                          Text('Departemen: $department',
                              style: const TextStyle(fontSize: 14)),
                          Text('Role: ${role.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: role == 'admin'
                                    ? Colors.red[700]
                                    : Colors.blue[700],
                              )),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (String result) {
                          if (result == 'edit') {
                            _addEditUser(userToEdit: userDoc);
                          } else if (result == 'delete') {
                            _deleteUser(userDoc.id, name);
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Edit Data'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Hapus Pengguna'),
                              ],
                            ),
                          ),
                        ],
                        icon: const Icon(Icons.more_vert),
                        tooltip: 'Opsi Lain',
                      ),
                      onTap: () {
                        log('Detail user $name diklik');
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
