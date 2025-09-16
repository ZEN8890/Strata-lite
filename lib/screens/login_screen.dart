import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:another_flushbar/flushbar.dart';
import 'dart:developer';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadRememberedUsername();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _loadRememberedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberedUsername = prefs.getString('remembered_username');
    if (rememberedUsername != null && rememberedUsername.isNotEmpty) {
      setState(() {
        _usernameController.text = rememberedUsername;
        _rememberMe = true;
      });
    }
  }

  void _saveRememberedUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('remembered_username', username);
    } else {
      await prefs.remove('remembered_username');
    }
  }

  void _performLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final String userInput = _usernameController.text.trim();
    final String password = _passwordController.text.trim();
    String email;

    if (userInput.contains('@')) {
      email = userInput;
    } else {
      email = '$userInput@strata.com';
    }

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        _saveRememberedUsername(userInput);

        if (!context.mounted) return;

        try {
          DocumentSnapshot userDoc =
              await _firestore.collection('users').doc(user.uid).get();
          if (userDoc.exists) {
            String role =
                (userDoc.data() as Map<String, dynamic>)['role'] ?? 'staff';
            if (role == 'admin') {
              _showNotification('Login Berhasil', 'Selamat datang, Admin!');
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, '/admin_dashboard');
            } else {
              _showNotification('Login Berhasil', 'Selamat datang, Staff!');
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, '/staff_dashboard');
            }
          } else {
            // Jika dokumen pengguna tidak ditemukan, buat yang baru dengan data default
            await _firestore.collection('users').doc(user.uid).set({
              'name': user.email?.split('@')[0] ?? 'Admin Pertama',
              'email': user.email,
              'phoneNumber': '',
              'department': 'IT',
              'role': 'admin',
              'createdAt': FieldValue.serverTimestamp(),
            });
            _showNotification('Login Berhasil', 'Selamat datang, Admin!');
            if (!context.mounted) return;
            Navigator.pushReplacementNamed(context, '/admin_dashboard');
          }
        } catch (e) {
          _showNotification('Error',
              'Gagal mengambil peran pengguna: $e. Dialihkan ke dasbor staff.',
              isError: true);
          if (!context.mounted) return;
          Navigator.pushReplacementNamed(context, '/staff_dashboard');
          log('Error fetching user role during login: $e');
        }
      } else {
        _showNotification('Login Gagal', 'Pengguna tidak ditemukan.',
            isError: true);
      }
    } on FirebaseAuthException catch (e) {
      log('Firebase Auth Error: ${e.code}');
      String errorMessage =
          'Gagal login. Mohon periksa kembali username dan password Anda.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        errorMessage = 'Username atau password salah.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Format input tidak valid.';
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Terlalu banyak percobaan login gagal. Coba lagi nanti.';
      }
      _showNotification('Login Gagal', errorMessage, isError: true);
    } catch (e) {
      log('Login Error: $e');
      _showNotification(
          'Login Gagal', 'Terjadi kesalahan yang tidak terduga: $e',
          isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/QR_logo.png', height: 120),
                const SizedBox(height: 48.0),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username atau Email Lengkap',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Input tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (bool? newValue) {
                        setState(() {
                          _rememberMe = newValue ?? false;
                        });
                      },
                    ),
                    const Text('Ingat Saya'),
                  ],
                ),
                const SizedBox(height: 24.0),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _performLogin,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Masuk'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
