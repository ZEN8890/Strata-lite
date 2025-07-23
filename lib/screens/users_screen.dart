import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore
import 'dart:developer'; // Untuk log.log()
import 'package:another_flushbar/flushbar.dart'; // Untuk notifikasi
import 'dart:async'; // Untuk Timer
import 'package:firebase_auth/firebase_auth.dart'; // Untuk membuat/mengupdate user Firebase Auth

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Timer? _notificationTimer; // Timer untuk mengontrol frekuensi notifikasi

  // Contoh daftar departemen (bisa diambil dari Firestore juga)
  final List<String> _departments = [
    'Marketing',
    'HRD',
    'Keamanan',
    'Keuangan',
    'Umum',
    'IT',
    'Logistik'
  ];
  final List<String> _roles = ['staff', 'admin']; // Daftar role yang tersedia

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

  // Fungsi untuk menambah atau mengedit pengguna
  Future<void> _addEditUser({DocumentSnapshot? userToEdit}) async {
    final bool isEditing = userToEdit != null;
    final _formKey = GlobalKey<FormState>(); // Key untuk form dialog

    TextEditingController nameController = TextEditingController(
        text: isEditing
            ? (userToEdit!.data() as Map<String, dynamic>)['name']
            : '');
    TextEditingController emailController = TextEditingController(
        text: isEditing
            ? (userToEdit!.data() as Map<String, dynamic>)['email']
            : '');
    TextEditingController phoneController = TextEditingController(
        text: isEditing
            ? (userToEdit!.data() as Map<String, dynamic>)['phoneNumber']
            : '');
    TextEditingController passwordController =
        TextEditingController(); // Hanya untuk akun baru atau reset password
    String? selectedDepartment = isEditing
        ? (userToEdit!.data() as Map<String, dynamic>)['department']
        : _departments.first;
    String? selectedRole = isEditing
        ? (userToEdit!.data() as Map<String, dynamic>)['role']
        : _roles.first;

    // Pastikan nilai default dropdown ada di daftar _departments dan _roles
    if (!isEditing && !_departments.contains(selectedDepartment)) {
      selectedDepartment = _departments.first;
    }
    if (!isEditing && !_roles.contains(selectedRole)) {
      selectedRole = _roles.first;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        // Gunakan dialogContext untuk AlertDialog
        title: Text(isEditing ? 'Edit Pengguna' : 'Tambah Pengguna Baru'),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
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
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  readOnly: isEditing,
                  validator: (value) {
                    if (value!.isEmpty) return 'Email tidak boleh kosong';
                    if (!value.contains('@') || !value.contains('.'))
                      return 'Format email tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Telepon',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  keyboardType: TextInputType.phone,
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
                  onChanged: (value) => selectedDepartment = value,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Pilih departemen'
                      : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: _roles
                      .map((role) => DropdownMenuItem(
                          value: role, child: Text(role.toUpperCase())))
                      .toList(),
                  onChanged: (value) => selectedRole = value,
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Pilih role' : null,
                ),
                const SizedBox(height: 10),
                if (!isEditing)
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password (min. 6 karakter)',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    obscureText: true,
                    validator: (value) => value!.length < 6
                        ? 'Password minimal 6 karakter'
                        : null,
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(), // Gunakan dialogContext
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                if (selectedDepartment == null || selectedDepartment!.isEmpty) {
                  _showNotification(
                      'Validasi Gagal', 'Departemen tidak boleh kosong.',
                      isError: true);
                  return;
                }
                if (selectedRole == null || selectedRole!.isEmpty) {
                  _showNotification(
                      'Validasi Gagal', 'Role tidak boleh kosong.',
                      isError: true);
                  return;
                }

                try {
                  if (isEditing) {
                    await _firestore
                        .collection('users')
                        .doc(userToEdit!.id)
                        .update({
                      'name': nameController.text.trim(),
                      'phoneNumber': phoneController.text.trim(),
                      'department': selectedDepartment,
                      'role': selectedRole,
                    });
                    _showNotification('Berhasil!',
                        'Pengguna ${nameController.text} berhasil diperbarui.',
                        isError: false);
                  } else {
                    try {
                      UserCredential userCredential =
                          await _auth.createUserWithEmailAndPassword(
                        email: emailController.text.trim(),
                        password: passwordController.text.trim(),
                      );
                      await _firestore
                          .collection('users')
                          .doc(userCredential.user!.uid)
                          .set({
                        'name': nameController.text.trim(),
                        'email': emailController.text.trim(),
                        'phoneNumber': phoneController.text.trim(),
                        'department': selectedDepartment,
                        'role': selectedRole,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      _showNotification('Akun Berhasil Dibuat!',
                          'Pengguna ${nameController.text} (${emailController.text}) berhasil ditambahkan.',
                          isError: false);

                      // PERBAIKAN DI SINI: Sign out the newly created user immediately
                      // This prevents the app from automatically logging in as this new user on next launch.
                      // Pastikan ada pengguna yang login sebelum mencoba sign out
                      if (_auth.currentUser != null) {
                        await _auth.signOut();
                        log('Newly created user signed out to prevent auto-login on next launch.');
                      }
                    } on FirebaseAuthException catch (e) {
                      String message;
                      if (e.code == 'email-already-in-use') {
                        message = 'Email ini sudah terdaftar.';
                      } else if (e.code == 'weak-password') {
                        message = 'Password terlalu lemah.';
                      } else {
                        message = 'Gagal membuat akun: ${e.message}';
                      }
                      _showNotification('Gagal!', message, isError: true);
                      return;
                    }
                  }
                  // PERBAIKAN DI SINI: Tutup dialog hanya setelah notifikasi ditampilkan dan operasi Auth selesai
                  // Menggunakan then() pada show() dari Flushbar
                  if (dialogContext.mounted) {
                    // Tampilkan notifikasi terlebih dahulu
                    Flushbar(
                      title: isEditing
                          ? 'Berhasil Diperbarui!'
                          : 'Akun Berhasil Dibuat!',
                      message: isEditing
                          ? 'Pengguna ${nameController.text} berhasil diperbarui.'
                          : 'Pengguna ${nameController.text} (${emailController.text}) berhasil ditambahkan.',
                      icon: const Icon(Icons.check_circle_outline,
                          color: Colors.green),
                      duration: const Duration(seconds: 3),
                      flushbarPosition: FlushbarPosition.TOP,
                      flushbarStyle: FlushbarStyle.FLOATING,
                      backgroundColor: Colors.green[100]!,
                      margin: const EdgeInsets.all(8),
                      borderRadius: BorderRadius.circular(8),
                    ).show(dialogContext).then((_) {
                      // Tutup dialog setelah Flushbar selesai
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    });
                  }
                } catch (e) {
                  _showNotification('Error', 'Terjadi kesalahan: $e',
                      isError: true);
                  log('Error adding/editing user: $e');
                }
              }
            },
            child: Text(isEditing ? 'Simpan Perubahan' : 'Tambah Pengguna'),
          ),
        ],
      ),
    );
  }

  // Fungsi untuk menghapus pengguna
  Future<void> _deleteUser(String userId, String userName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus Pengguna'),
        content: Text(
            'Apakah Anda yakin ingin menghapus pengguna "$userName"? Ini akan menghapus data profil dari database. Akun login Firebase Authentication mungkin perlu dihapus secara manual dari Firebase Console atau melalui Cloud Function untuk keamanan yang lengkap.'),
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

    if (confirm == true) {
      try {
        // Hapus dokumen pengguna dari Firestore
        await _firestore.collection('users').doc(userId).delete();

        // PENTING: Menghapus akun dari Firebase Authentication (Auth)
        // tidak bisa dilakukan langsung dari client-side Flutter untuk user lain
        // karena alasan keamanan. Anda membutuhkan:
        // 1. Cloud Functions: Untuk menghapus user dari Auth setelah dokumennya dihapus dari Firestore.
        //    (Disarankan: Trigger on delete Firestore document)
        // 2. Admin SDK di backend Anda: Jika Anda memiliki server sendiri.
        //
        // Jika tidak diimplementasikan, akun Auth akan tetap ada meskipun dokumen profilnya hilang.
        // Ini adalah BUG SECURITY/DATA INCONSISTENCY jika tidak ditangani di backend.
        log('Attempted to delete user document from Firestore: $userId');
        _showNotification('Berhasil Dihapus',
            'Data profil pengguna "$userName" berhasil dihapus dari database. Akun login Firebase Authentication mungkin masih aktif.',
            isError: false);
      } catch (e) {
        _showNotification('Gagal Menghapus',
            'Gagal menghapus pengguna "$userName": $e. Pastikan Anda memiliki izin yang cukup.',
            isError: true);
        log('Error deleting user: $e');
      }
    }
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
                  hintText: 'Cari pengguna (nama, email, departemen, role)...',
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
              Expanded(
                child: Text(
                  'Daftar Pengguna Terdaftar:',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
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
                final String department =
                    (data['department'] ?? '').toLowerCase();
                final String role = (data['role'] ?? '').toLowerCase();
                final String phoneNumber =
                    (data['phoneNumber'] ?? '').toLowerCase();

                return name.contains(lowerCaseQuery) ||
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
                  final String phoneNumber = userData['phoneNumber'] ?? 'N/A';
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
                          Text('Telepon: $phoneNumber',
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: 'Edit User',
                            onPressed: () => _addEditUser(userToEdit: userDoc),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Hapus User',
                            onPressed: () => _deleteUser(userDoc.id, name),
                          ),
                        ],
                      ),
                      onTap: () {
                        log('Detail user ${name} diklik');
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
