// functions/index.js

const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Inisialisasi Firebase Admin SDK
// Ini penting agar Cloud Function memiliki hak akses admin ke proyek Firebase Anda
admin.initializeApp();

// Fungsi HTTP Callable untuk membuat pengguna baru oleh admin
// Ini akan dipanggil dari aplikasi Flutter Anda
exports.createUserByAdmin = functions.https.onCall(async (data, context) => {
  // 1. Validasi Autentikasi dan Role Admin
  // Pastikan hanya pengguna yang terautentikasi dan memiliki role 'admin'
  // yang bisa memanggil fungsi ini
  if (!context.auth || !context.auth.token || context.auth.token.role !== "admin") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Hanya admin yang dapat membuat pengguna baru.",
    );
  }

  // 2. Ambil data dari permintaan klien
  const {
    email,
    password,
    name,
    phoneNumber,
    department,
    role,
  } = data;

  // 3. Validasi input data
  if (!email || !password || !name || !department || !role) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Data pengguna tidak lengkap. Email, password, nama, departemen, " +
        "dan role harus disediakan.",
    );
  }
  if (password.length < 6) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Password harus minimal 6 karakter.",
    );
  }
  if (!["staff", "admin"].includes(role)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Role tidak valid. Hanya \"staff\" atau \"admin\" yang diizinkan.",
    );
  }

  try {
    // 4. Buat pengguna di Firebase Authentication
    // admin.auth().createUser() TIDAK akan otomatis mencatat masuk pengguna
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: name, // Nama tampilan di Firebase Auth
      phoneNumber: phoneNumber || null, // Nomor telepon opsional
    });

    // 5. Atur Custom Claims (Role) untuk pengguna baru
    // Ini penting agar aplikasi Flutter dapat membaca role pengguna
    await admin.auth().setCustomUserClaims(userRecord.uid, {role: role});

    // 6. Simpan data profil tambahan ke Firestore
    await admin.firestore().collection("users").doc(userRecord.uid).set({
      name: name,
      email: email,
      phoneNumber: phoneNumber,
      department: department,
      role: role,
      createdAt: admin.firestore.FieldValue.serverTimestamp(), // Timestamp server
    });

    // 7. Berikan respons sukses ke klien
    return {success: true, message: `Pengguna ${name} (${email}) berhasil dibuat.`};
  } catch (error) {
    // Tangani error spesifik dari Firebase Auth
    if (error.code === "auth/email-already-in-use") {
      throw new functions.https.HttpsError(
        "already-exists",
        "Email ini sudah terdaftar untuk akun lain.",
      );
    }
    if (error.code === "auth/invalid-email") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Format email tidak valid.",
      );
    }
    if (error.code === "auth/weak-password") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Password terlalu lemah.",
      );
    }
    // Tangani error umum
    console.error("Error creating user:", error);
    throw new functions.https.HttpsError(
      "internal",
      `Gagal membuat pengguna: ${error.message || "Terjadi kesalahan tidak dikenal."}`,
    );
  }
});

// Fungsi HTTP Callable untuk menghapus pengguna oleh admin
exports.deleteUserByAdmin = functions.https.onCall(async (data, context) => {
  // 1. Validasi Autentikasi dan Role Admin
  if (!context.auth || !context.auth.token || context.auth.token.role !== "admin") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Hanya admin yang dapat menghapus pengguna.",
    );
  }

  // 2. Ambil UID pengguna yang akan dihapus
  const {uid} = data;

  if (!uid) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "UID pengguna tidak disediakan.",
    );
  }

  // 3. Pastikan admin tidak menghapus dirinya sendiri (opsional tapi disarankan)
  if (context.auth.uid === uid) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Admin tidak dapat menghapus akunnya sendiri melalui fitur ini.",
    );
  }

  try {
    // 4. Hapus pengguna dari Firebase Authentication
    await admin.auth().deleteUser(uid);

    // 5. Hapus dokumen profil pengguna dari Firestore
    await admin.firestore().collection("users").doc(uid).delete();

    // 6. Berikan respons sukses ke klien
    return {success: true, message: `Pengguna dengan UID ${uid} berhasil dihapus.`};
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      throw new functions.https.HttpsError(
        "not-found",
        "Pengguna tidak ditemukan.",
      );
    }
    console.error("Error deleting user:", error);
    throw new functions.https.HttpsError(
      "internal",
      `Gagal menghapus pengguna: ${error.message || "Terjadi kesalahan tidak dikenal."}`,
    );
  }
});

// Fungsi HTTP Callable untuk mengupdate pengguna oleh admin
exports.updateUserByAdmin = functions.https.onCall(async (data, context) => {
  // 1. Validasi Autentikasi dan Role Admin
  if (!context.auth || !context.auth.token || context.auth.token.role !== "admin") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Hanya admin yang dapat mengupdate pengguna.",
    );
  }

  // 2. Ambil data dari permintaan klien
  const {uid, name, phoneNumber, department, role} = data;

  // 3. Validasi input data
  if (!uid || !name || !department || !role) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "UID, nama, departemen, dan role harus disediakan.",
    );
  }
  if (!["staff", "admin"].includes(role)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Role tidak valid. Hanya \"staff\" atau \"admin\" yang diizinkan.",
    );
  }

  try {
    // 4. Update pengguna di Firebase Authentication (display name, phone number)
    // Email tidak bisa diubah di sini, perlu fungsi terpisah jika diperlukan
    await admin.auth().updateUser(uid, {
      displayName: name,
      phoneNumber: phoneNumber || null,
    });

    // 5. Update Custom Claims (Role)
    await admin.auth().setCustomUserClaims(uid, {role: role});

    // 6. Update data profil tambahan di Firestore
    await admin.firestore().collection("users").doc(uid).update({
      name: name,
      phoneNumber: phoneNumber,
      department: department,
      role: role,
      // createdAt tidak diupdate karena itu adalah timestamp pembuatan
    });

    // 7. Berikan respons sukses ke klien
    return {success: true, message: `Pengguna ${name} berhasil diupdate.`};
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      throw new functions.https.HttpsError(
        "not-found",
        "Pengguna tidak ditemukan.",
      );
    }
    console.error("Error updating user:", error);
    throw new functions.https.HttpsError(
      "internal",
      `Gagal mengupdate pengguna: ${error.message || "Terjadi kesalahan tidak dikenal."}`,
    );
  }
});