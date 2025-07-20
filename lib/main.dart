// File: main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Strata_lite/screens/admin_dashboard_screen.dart';
import 'package:Strata_lite/screens/login_screen.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:Strata_lite/firebase_options.dart'; // Import file konfigurasi Firebase
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth

void main() async {
  // Pastikan fungsi main() bersifat async
  WidgetsFlutterBinding
      .ensureInitialized(); // Penting: Pastikan Flutter binding sudah diinisialisasi

  // --- INISIALISASI FIREBASE ---
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // --- AKHIR INISIALISASI FIREBASE ---

  // --- LOGIKA UNTUK MEMERIKSA STATUS LOGIN SAAT APLIKASI DIMULAI ---
  // Dapatkan instance Firebase Auth
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Periksa apakah ada pengguna yang sedang login
  User? currentUser = _auth.currentUser;

  String initialRoute;
  if (currentUser != null) {
    // Jika ada pengguna yang login, langsung arahkan ke dashboard admin
    // TODO: Di sini Anda juga bisa mengecek peran pengguna dari Firestore
    // untuk mengarahkan ke dashboard admin atau staff yang sesuai.
    initialRoute = '/admin_dashboard';
  } else {
    // Jika tidak ada pengguna yang login, arahkan ke halaman login
    initialRoute = '/';
  }
  // --- AKHIR LOGIKA STATUS LOGIN ---

  // Menyembunyikan System UI Overlay (Navigation Bar Android)
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode
        .immersiveSticky, // Ini akan menyembunyikan navigation bar dan status bar
    overlays: [], // Menentukan overlay apa yang harus disembunyikan (mengosongkan berarti semua)
  ).then((_) {
    // Opsional: Atur orientasi layar jika diperlukan (misalnya, hanya portrait)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]).then((_) {
      runApp(MyApp(initialRoute: initialRoute)); // Kirim initialRoute ke MyApp
    });
  });
}

class MyApp extends StatelessWidget {
  final String initialRoute; // Tambahkan properti initialRoute

  const MyApp({super.key, required this.initialRoute}); // Perbarui konstruktor

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistem Barcode Strata Lite',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: initialRoute, // Gunakan initialRoute yang ditentukan
      routes: {
        '/': (context) => const LoginScreen(),
        '/admin_dashboard': (context) => const AdminDashboardScreen(),
        // TODO: Tambahkan rute untuk halaman staff, jika ada
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
