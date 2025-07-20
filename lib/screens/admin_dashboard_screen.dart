import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import untuk SystemNavigator.pop()
import 'package:Strata_lite/screens/add_item_screen.dart';
import 'package:Strata_lite/screens/item_list_screen.dart';
import 'package:Strata_lite/screens/time_log_screen.dart';
import 'package:Strata_lite/screens/take_item_screen.dart';
import 'package:Strata_lite/screens/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  String _drawerUserName = 'Memuat Nama...';
  String _drawerUserEmail = 'Memuat Email...';
  String _drawerUserDepartment = 'Memuat Departemen...';
  bool _isDrawerLoading = true; // Inisialisasi dengan true

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<Widget> _pages = [
    const ItemListScreen(),
    const AddItemScreen(),
    const Center(child: Text('Halaman Impor/Ekspor Data (Segera Hadir!)')),
    const TimeLogScreen(),
    const SettingsScreen(),
    const TakeItemScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadDrawerUserData(); // Muat data pengguna saat initState
  }

  // Fungsi untuk memuat data pengguna untuk DrawerHeader
  Future<void> _loadDrawerUserData() async {
    // Set loading state di awal
    if (!mounted) return;
    setState(() {
      _isDrawerLoading = true;
    });

    User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      if (!mounted) return;
      setState(() {
        _drawerUserEmail = 'Tidak Login';
        _drawerUserName = 'Pengguna Tamu';
        _drawerUserDepartment = '';
        _isDrawerLoading = false; // Set ke false jika tidak ada user
      });
      log('Error: No user logged in for dashboard drawer.');
      return;
    }

    // Set email dari Firebase Auth terlebih dahulu
    if (!mounted) return;
    setState(() {
      _drawerUserEmail = currentUser.email ?? 'Email Tidak Tersedia';
    });

    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (!mounted) return; // Cek mounted setelah await

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _drawerUserName =
              userData['name'] ?? currentUser.email ?? 'Nama Tidak Ditemukan';
          _drawerUserDepartment =
              userData['department'] ?? 'Departemen Tidak Ditemukan';
        });
      } else {
        setState(() {
          _drawerUserName = currentUser.email ??
              'Nama Tidak Ditemukan'; // Fallback ke email jika dokumen tidak ada
          _drawerUserDepartment = 'Data Profil Tidak Lengkap';
        });
        log('Warning: User document not found in Firestore for UID: ${currentUser.uid}');
      }
    } catch (e) {
      log('Error loading drawer user data from Firestore: $e');
      if (!mounted) return; // Cek mounted di catch block
      setState(() {
        _drawerUserName = currentUser.email ?? 'Error Memuat Nama';
        _drawerUserDepartment = 'Error Memuat Departemen';
      });
    } finally {
      if (!mounted) return; // Penting: Cek mounted di finally block
      setState(() {
        _isDrawerLoading = false; // Pastikan ini selalu diatur ke false
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Fungsi untuk menampilkan dialog konfirmasi logout
  Future<void> _confirmLogout() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Lakukan logout Firebase
              await FirebaseAuth.instance.signOut();
              if (!mounted) return; // Cek mounted setelah await signOut()
              // Opsi 1: Kembali ke halaman login (disarankan jika aplikasi tetap berjalan)
              Navigator.pushReplacementNamed(context, '/');
              // Opsi 2: Menutup aplikasi sepenuhnya (seperti tombol back di root)
              // SystemNavigator.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    // Jika konfirmasi dari dialog adalah false (batal), maka tidak ada yang dilakukan
    // Jika true, logika logout sudah ditangani di dalam dialog onPressed.
    // Jika dialog ditutup tanpa pilihan (null), juga tidak ada yang dilakukan.
  }

  @override
  Widget build(BuildContext context) {
    // PopScope untuk menangani tombol back fisik (Android)
    return PopScope(
      canPop:
          false, // Ini mencegah pop otomatis. Kita akan menanganinya secara manual.
      onPopInvoked: (bool didPop) async {
        if (didPop) {
          // Jika sistem sudah menangani pop (misal, karena gestur di iOS),
          // atau jika halaman sudah di-pop oleh navigasi lain,
          // kita tidak perlu melakukan apa-apa lagi di sini.
          return;
        }
        // Panggil dialog konfirmasi logout
        await _confirmLogout();
        // Setelah _confirmLogout selesai, PopScope secara implisit
        // akan memeriksa kembali apakah halaman ini harus di-pop
        // berdasarkan status navigasi yang mungkin berubah setelah logout.
        // Jika logout berhasil dan Navigator.pushReplacementNamed(context, '/'); dipanggil,
        // maka halaman ini akan otomatis hilang dari stack.
        // Jika _confirmLogout memicu SystemNavigator.pop(), aplikasi akan tertutup.
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard Admin Strata Lite'),
          // Hapus atau komentari bagian 'actions' untuk menghilangkan tombol logout di AppBar
          // actions: [
          //   IconButton(
          //     icon: const Icon(Icons.logout),
          //     tooltip: 'Logout',
          //     onPressed: _confirmLogout,
          //   ),
          // ],
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: Colors.blue,
                ),
                child: _isDrawerLoading // Menampilkan loading atau konten
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.person,
                                size: 40, color: Colors.blue),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _drawerUserName, // Menampilkan nama user
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _drawerUserEmail, // Menampilkan email user
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          if (_drawerUserDepartment
                              .isNotEmpty) // Menampilkan departemen jika ada
                            Text(
                              _drawerUserDepartment,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
              ),
              ListTile(
                leading: const Icon(Icons.inventory),
                title: const Text('Manajemen Barang'),
                onTap: () {
                  _onItemTapped(0);
                  Navigator.pop(context); // Tutup drawer
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_box),
                title: const Text('Tambah Barang Baru'),
                onTap: () {
                  _onItemTapped(1);
                  Navigator.pop(context); // Tutup drawer
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Log Pengambilan Barang'),
                onTap: () {
                  _onItemTapped(3);
                  Navigator.pop(context); // Tutup drawer
                },
              ),
              ListTile(
                leading: const Icon(Icons.shopping_cart),
                title: const Text('Ambil Barang'),
                onTap: () {
                  _onItemTapped(5);
                  Navigator.pop(context); // Tutup drawer
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Pengaturan'),
                onTap: () {
                  _onItemTapped(4);
                  Navigator.pop(context); // Tutup drawer
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: _confirmLogout, // Panggil fungsi konfirmasi logout
              ),
            ],
          ),
        ),
        body: _pages[_selectedIndex],
      ),
    );
  }
}
