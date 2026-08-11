package id.rataapk.template;

import android.content.Context;
import android.content.SharedPreferences;

import java.util.HashSet;
import java.util.Set;
import java.util.TreeSet;

/**
 * Mengelola penyimpanan & validasi PIN.
 *
 * - PIN Admin bersifat TETAP (hardcode) = 987871. Tidak disimpan di
 *   SharedPreferences, tidak bisa dihapus/diubah dari dalam aplikasi.
 * - PIN Pengguna bersifat DINAMIS: ditambah/dihapus oleh Admin lewat
 *   AdminActivity, disimpan lokal di perangkat lewat SharedPreferences.
 *
 * Catatan: karena ini aplikasi WebView single-APK tanpa server backend
 * untuk otentikasi, daftar PIN pengguna ini tersimpan per perangkat
 * (device), bukan terpusat. Admin perlu login di tiap perangkat yang mau
 * didaftarkan PIN-nya, atau tambahkan PIN default sebelum build APK
 * dibagikan ke pengguna.
 */
public class PrefsHelper {

    /** PIN khusus admin. Ganti nilai ini kalau Anda mau PIN admin lain. */
    public static final String ADMIN_PIN = "987871";

    private static final String PREFS_NAME = "rataapk_prefs";
    private static final String KEY_USER_PINS = "user_pins";

    private final SharedPreferences prefs;

    public PrefsHelper(Context context) {
        prefs = context.getApplicationContext()
                .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }

    public boolean isAdminPin(String pin) {
        return ADMIN_PIN.equals(pin);
    }

    public boolean isValidUserPin(String pin) {
        return getUserPins().contains(pin);
    }

    /** Mengembalikan salinan terurut dari daftar PIN pengguna yang aktif. */
    public Set<String> getUserPins() {
        Set<String> stored = prefs.getStringSet(KEY_USER_PINS, new HashSet<>());
        return new TreeSet<>(stored);
    }

    /**
     * Menambah PIN pengguna baru.
     *
     * @return true kalau berhasil ditambah, false kalau PIN sudah ada
     *         atau sama dengan PIN admin.
     */
    public boolean addUserPin(String pin) {
        if (isAdminPin(pin)) return false;
        Set<String> current = new HashSet<>(prefs.getStringSet(KEY_USER_PINS, new HashSet<>()));
        if (current.contains(pin)) return false;
        current.add(pin);
        prefs.edit().putStringSet(KEY_USER_PINS, current).apply();
        return true;
    }

    public void removeUserPin(String pin) {
        Set<String> current = new HashSet<>(prefs.getStringSet(KEY_USER_PINS, new HashSet<>()));
        current.remove(pin);
        prefs.edit().putStringSet(KEY_USER_PINS, current).apply();
    }
}
