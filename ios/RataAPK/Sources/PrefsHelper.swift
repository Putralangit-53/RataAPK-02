import Foundation

/// Mengelola penyimpanan & validasi PIN.
///
/// - PIN Admin bersifat TETAP (hardcode) = 987871. Tidak disimpan di
///   UserDefaults, tidak bisa dihapus/diubah dari dalam aplikasi.
/// - PIN Pengguna bersifat DINAMIS: ditambah/dihapus oleh Admin lewat
///   AdminViewController, disimpan lokal di perangkat lewat UserDefaults.
///
/// Catatan: sama seperti versi Android, ini aplikasi WebView single-app
/// tanpa server backend untuk otentikasi, jadi daftar PIN pengguna
/// tersimpan per perangkat (device), bukan terpusat.
enum PrefsHelper {

    /// PIN khusus admin. Ganti nilai ini kalau Anda mau PIN admin lain.
    static let adminPin = "987871"

    private static let userPinsKey = "rataapk_user_pins"

    static func isAdminPin(_ pin: String) -> Bool {
        return adminPin == pin
    }

    /// Mengembalikan salinan terurut dari daftar PIN pengguna yang aktif.
    static func userPins() -> [String] {
        let stored = UserDefaults.standard.stringArray(forKey: userPinsKey) ?? []
        return stored.sorted()
    }

    static func isValidUserPin(_ pin: String) -> Bool {
        return userPins().contains(pin)
    }

    /// Menambah PIN pengguna baru.
    /// - Returns: true kalau berhasil ditambah, false kalau PIN sudah ada
    ///   atau sama dengan PIN admin.
    @discardableResult
    static func addUserPin(_ pin: String) -> Bool {
        if isAdminPin(pin) { return false }
        var current = Set(UserDefaults.standard.stringArray(forKey: userPinsKey) ?? [])
        if current.contains(pin) { return false }
        current.insert(pin)
        UserDefaults.standard.set(Array(current), forKey: userPinsKey)
        return true
    }

    static func removeUserPin(_ pin: String) {
        var current = Set(UserDefaults.standard.stringArray(forKey: userPinsKey) ?? [])
        current.remove(pin)
        UserDefaults.standard.set(Array(current), forKey: userPinsKey)
    }
}
