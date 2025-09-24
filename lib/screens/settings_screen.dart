import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';
import 'package:another_flushbar/flushbar.dart';
import 'dart:async';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();

  String? _selectedDepartment;

  bool _isLoading = true;
  bool _isResettingPassword = false;
  String? _errorMessage;

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

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  void _showNotification(String title, String message, {bool isError = false}) {
    if (!context.mounted) return;

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
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _currentUser = _auth.currentUser;

    if (_currentUser == null) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Tidak ada pengguna yang login.';
        _isLoading = false;
      });
      log('Error: No user logged in for settings screen.');
      return;
    }

    _emailController.text = _currentUser!.email ?? 'N/A';

    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(_currentUser!.uid).get();

      if (!mounted) return;
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        _nameController.text = userData['name'] ?? '';
        _selectedDepartment = userData['department'];
        log('User data loaded: Name=${_nameController.text}, Email=${_emailController.text}, Department=$_selectedDepartment');
      } else {
        _nameController.text = 'Nama Tidak Ditemukan';
        _selectedDepartment = null;
        log('Warning: User document not found in Firestore for UID: ${_currentUser!.uid}');
      }
    } catch (e) {
      if (!mounted) return;
      _errorMessage = 'Gagal memuat data profil: $e';
      log('Error loading user data from Firestore: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUserData() async {
    if (_currentUser == null) {
      _showNotification('Error', 'Tidak ada pengguna yang login.',
          isError: true);
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      _showNotification('Input Tidak Lengkap', 'Nama tidak boleh kosong.',
          isError: true);
      return;
    }

    if (_selectedDepartment == null || _selectedDepartment!.isEmpty) {
      _showNotification('Input Tidak Lengkap', 'Departemen tidak boleh kosong.',
          isError: true);
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      await _firestore.collection('users').doc(_currentUser!.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'department': _selectedDepartment,
      }, SetOptions(merge: true));

      if (!mounted) return;
      _showNotification('Berhasil!', 'Profil berhasil diperbarui.',
          isError: false);
      log('User data updated successfully for UID: ${_currentUser!.uid}');
    } catch (e) {
      if (!mounted) return;
      _showNotification('Gagal Memperbarui Profil', 'Error: $e', isError: true);
      log('Error updating user data: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    bool _obscureNewPassword = true;
    bool _obscureCurrentPassword = true;

    final _formKey = GlobalKey<FormState>();

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: const Text('Reset Password'),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _currentPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Sandi Saat Ini',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureCurrentPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setStateSB(() {
                              _obscureCurrentPassword =
                                  !_obscureCurrentPassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscureCurrentPassword,
                      validator: (value) =>
                          value!.isEmpty ? 'Sandi tidak boleh kosong.' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _newPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Sandi Baru (min. 6 karakter)',
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
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.of(dialogContext).pop(true);
                  }
                },
                child: const Text('Reset'),
              ),
            ],
          );
        },
      ),
    );

    if (confirm != true) {
      _newPasswordController.clear();
      _currentPasswordController.clear();
      return;
    }

    if (!mounted) return;
    setState(() {
      _isResettingPassword = true;
    });

    try {
      log('Mencoba otentikasi ulang pengguna...');
      // Otentikasi ulang pengguna dengan sandi saat ini dengan timeout
      AuthCredential credential = EmailAuthProvider.credential(
        email: _currentUser!.email!,
        password: _currentPasswordController.text.trim(),
      );
      await _currentUser!
          .reauthenticateWithCredential(credential)
          .timeout(const Duration(seconds: 10));
      log('Otentikasi ulang berhasil.');

      log('Mencoba memperbarui sandi...');
      // Langsung perbarui sandi setelah otentikasi ulang berhasil
      await _currentUser!
          .updatePassword(_newPasswordController.text.trim())
          .timeout(const Duration(seconds: 10));
      log('Pembaruan sandi berhasil.');

      // Panggil notifikasi hanya setelah proses berhasil dan dialog ditutup
      if (!mounted) return;
      _showNotification('Berhasil!', 'Password berhasil direset.',
          isError: false);
      _newPasswordController.clear();
      _currentPasswordController.clear();
    } on TimeoutException {
      if (!mounted) return;
      _showNotification('Gagal!',
          'Permintaan memakan waktu terlalu lama. Periksa koneksi internet Anda.',
          isError: true);
      log('Timeout Exception: Permintaan otentikasi ulang/pembaruan sandi gagal karena timeout.');
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Sandi saat ini salah.';
      } else if (e.code == 'weak-password') {
        message = 'Sandi terlalu lemah.';
      } else {
        message = 'Gagal mereset sandi: ${e.message}';
      }
      if (!mounted) return;
      _showNotification('Gagal!', message, isError: true);
      log('Error resetting password: ${e.code} - ${e.message}');
    } catch (e) {
      if (!mounted) return;
      _showNotification('Gagal!', 'Terjadi kesalahan umum: $e', isError: true);
      log('Error resetting password: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isResettingPassword = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView(
                  children: [
                    Text(
                      'Pengaturan Profil',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    Card(
                      margin: EdgeInsets.zero,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nama Lengkap: dibuat readOnly
                            TextField(
                              controller: _nameController,
                              readOnly: true, // <-- Perubahan di sini
                              decoration: const InputDecoration(
                                labelText: 'Nama Lengkap',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
                            ),
                            const SizedBox(height: 15),
                            TextField(
                              controller: _emailController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email),
                              ),
                            ),
                            const SizedBox(height: 15),
                            // Departemen: Dibuat tidak bisa diubah dengan menonaktifkan onChanged
                            DropdownButtonFormField<String>(
                              value: _selectedDepartment,
                              onChanged: null, // <-- Perubahan di sini
                              decoration: const InputDecoration(
                                labelText: 'Departemen',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.business),
                              ),
                              items: _departments.map((String department) {
                                return DropdownMenuItem<String>(
                                  value: department,
                                  child: Text(department),
                                );
                              }).toList(),
                              // Validator dihapus karena onChanged null, jadi tidak perlu divalidasi
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _isResettingPassword ? null : _resetPassword,
                        icon: _isResettingPassword
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.lock_reset),
                        label: Text(_isResettingPassword
                            ? 'Mereset...'
                            : 'Reset Password'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
