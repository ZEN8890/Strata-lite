import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Strata_lite/screens/admin_dashboard_screen.dart';
import 'package:Strata_lite/screens/staff_dashboard_screen.dart'; // <--- Import StaffDashboardScreen
import 'package:Strata_lite/screens/login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:Strata_lite/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- Import Cloud Firestore

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore =
      FirebaseFirestore.instance; // <--- Instance Firestore

  String initialRoute;
  User? currentUser = auth.currentUser;

  if (currentUser != null) {
    // Ambil role pengguna dari Firestore
    try {
      DocumentSnapshot userDoc =
          await firestore.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        String role = (userDoc.data() as Map<String, dynamic>)['role'] ??
            'staff'; // Default ke staff jika role tidak ada
        if (role == 'admin') {
          initialRoute = '/admin_dashboard';
        } else {
          initialRoute = '/staff_dashboard'; // Arahkan ke staff dashboard
        }
      } else {
        // Jika dokumen user tidak ditemukan, perlakukan sebagai staff atau arahkan ke login
        initialRoute = '/staff_dashboard';
        print(
            'Warning: User document not found for UID: ${currentUser.uid}, defaulting to staff dashboard.');
      }
    } catch (e) {
      print('Error fetching user role: $e, defaulting to staff dashboard.');
      initialRoute =
          '/staff_dashboard'; // Fallback jika ada error saat mengambil role
    }
  } else {
    initialRoute = '/';
  }

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  ).then((_) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]).then((_) {
      runApp(MyApp(initialRoute: initialRoute));
    });
  });
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistem Barcode Strata Lite',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: initialRoute,
      routes: {
        '/': (context) => const LoginScreen(),
        '/admin_dashboard': (context) => const AdminDashboardScreen(),
        '/staff_dashboard': (context) =>
            const StaffDashboardScreen(), // <--- Tambahkan rute ini
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
