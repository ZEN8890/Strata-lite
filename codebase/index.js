const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Inisialisasi Firebase Admin SDK
// Penting: Di lingkungan Cloud Functions, ini akan otomatis terautentikasi dengan
// kredensial proyek Anda. Jika Anda menjalankan di emulator lokal, pastikan
// service account credential sudah diatur sesuai dokumentasi Firebase.
admin.initializeApp();

// ====================================================================================
// 1. Fungsi HTTPS yang Dapat Dipanggil: createUserAndProfile
//    Membuat pengguna di Firebase Auth dan profil di Firestore.
//    Dipanggil dari aplikasi Flutter Anda.
// ====================================================================================
exports.createUserAndProfile = functions.https.onCall(async (data, context) => {
  // Validasi Autentikasi (SANGAT DISARANKAN): Pastikan hanya admin yang memanggil ini.
  // Ini adalah contoh dasar, Anda bisa memperketatnya dengan klaim kustom admin.
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Authentication required. Only authenticated users can call this function.",
    );
  }

  // Ambil Data dari Panggilan Klien
  const {name, email, password, phoneNumber, department, role} = data;

  // Validasi input
  if (!email || !password || !name || !department || !role) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Required data (email, password, name, department, role) is missing.",
    );
  }
  if (password.length < 6) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Password must be at least 6 characters long.",
    );
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Invalid email format.",
    );
  }

  try {
    // Buat Pengguna di Firebase Authentication
    // Catatan: Ini TIDAK akan secara otomatis login pengguna di sisi klien
    // karena dijalankan di lingkungan server.
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: name, // Opsional: simpan nama di Auth juga
      phoneNumber: phoneNumber || null, // Jika phoneNumber kosong, set null
    });

    // Simpan Data Profil Pengguna di Cloud Firestore
    await admin.firestore().collection("users").doc(userRecord.uid).set({
      name: name,
      email: email,
      phoneNumber: phoneNumber || "",
      department: department,
      role: role,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      uid: userRecord.uid, // Simpan UID juga di dokumen Firestore untuk referensi
    });

    // Opsional: Atur Klaim Kustom untuk peran (role) pengguna baru
    // Ini sangat berguna untuk aturan keamanan Firestore dan pengecekan role di klien
    await admin.auth().setCustomUserClaims(userRecord.uid, {role: role});

    console.log(`Pengguna baru dibuat: ${userRecord.uid} (${email})`);

    return {success: true, message: "User created successfully."};
  } catch (error) {
    console.error("Error creating user in Cloud Function:", error);

    let errorMessage = "An error occurred while creating the user.";
    // Tangani error spesifik dari Firebase Auth
    if (error.code === "auth/email-already-in-use") {
      errorMessage = "This email is already registered.";
    } else if (error.code === "auth/weak-password") {
      errorMessage = "The password is too weak.";
    } else if (error.message) { // Fallback to Firebase error message
      errorMessage = error.message;
    }

    // Lempar error HTTPSCallable untuk ditangkap di sisi klien
    throw new functions.https.HttpsError("internal", errorMessage);
  }
});

// ====================================================================================
// 2. Fungsi Trigger Firestore: deleteUserAuthOnProfileDelete
//    Otomatis menghapus akun Firebase Auth saat dokumen profil pengguna di Firestore dihapus.
// ====================================================================================
exports.deleteUserAuthOnProfileDelete = functions.firestore
  .document("users/{userId}") // Mendengarkan penghapusan di koleksi 'users'
  .onDelete(async (snap, context) => {
    const userId = context.params.userId; // Ambil UID dari path dokumen yang dihapus
    try {
      await admin.auth().deleteUser(userId); // Hapus akun dari Firebase Auth
      console.log(`Firebase Auth account for UID ${userId} deleted successfully.`);
      return null; // Mengembalikan null untuk menandakan operasi selesai tanpa error
    } catch (error) {
      console.error(`Failed to delete Firebase Auth account for UID ${userId}:`, error);
      // Jika user tidak ditemukan di Auth (misalnya sudah dihapus secara manual),
      // anggap itu bukan error fatal.
      if (error.code === "auth/user-not-found") {
        console.warn(`Auth user with UID ${userId} not found, likely already deleted.`);
        return null;
      }
      // Lempar error jika ada masalah lain yang tidak terduga
      throw new functions.https.HttpsError("internal", `Failed to delete Auth account: ${error.message}`);
    }
  });