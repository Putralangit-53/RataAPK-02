package id.rataapk.template;

import android.annotation.SuppressLint;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.provider.OpenableColumns;
import android.view.Menu;
import android.view.MenuItem;
import android.webkit.MimeTypeMap;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.Toolbar;
import androidx.core.content.FileProvider;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

public class MainActivity extends AppCompatActivity {

    public static final String EXTRA_MODE = "extra_mode";
    public static final String MODE_ADMIN = "admin";
    public static final String MODE_USER = "user";

    private String mode = MODE_USER;
    private WebView webView;

    /**
     * Menyimpan label jenis konversi ("HTML Upload", "ZIP Project", dst)
     * yang sedang diproses, dipakai lagi setelah pengguna selesai memilih
     * file dari file picker sistem.
     */
    private String labelJenisAktif = "";

    /** true = hasil pilih file akan diproses lewat alur "Build Otomatis" (GitHub API),
     *  false = hasil pilih file akan dibagikan manual (share sheet biasa). */
    private boolean modeBuildOtomatisAktif = false;

    private final ActivityResultLauncher<String[]> pemilihFile = registerForActivityResult(
            new ActivityResultContracts.OpenDocument(),
            uri -> {
                if (uri != null) {
                    if (modeBuildOtomatisAktif) {
                        prosesFileUntukBuildOtomatis(uri, labelJenisAktif);
                    } else {
                        prosesFileTerpilih(uri, labelJenisAktif);
                    }
                }
            }
    );

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        mode = getIntent().getStringExtra(EXTRA_MODE);
        if (mode == null) mode = MODE_USER;

        Toolbar toolbar = findViewById(R.id.toolbarMain);
        setSupportActionBar(toolbar);
        if (getSupportActionBar() != null) {
            String judul = getString(R.string.app_name)
                    + (MODE_ADMIN.equals(mode) ? " \u2022 " + getString(R.string.admin_mode_badge) : "");
            getSupportActionBar().setTitle(judul);
        }

        webView = findViewById(R.id.webView);
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setAllowFileAccess(true);

        // Tetap di dalam WebView untuk semua navigasi, tidak lempar ke browser luar
        webView.setWebViewClient(new WebViewClient());

        // PENTING: tanpa WebChromeClient, WebView Android MEMBISUKAN
        // alert()/confirm()/prompt() dari JavaScript (dianggap no-op, tidak
        // ada dialog yang muncul sama sekali) — makanya kartu "Website / URL"
        // di dashboard (yang pakai prompt()) sebelumnya terlihat seperti
        // tidak berfungsi. Baris ini yang mengaktifkan dialog-dialog itu.
        webView.setWebChromeClient(new WebChromeClient());

        // Jembatan JS <-> Android supaya kartu "Konversi" di dashboard
        // benar-benar bisa memilih & membagikan file, bukan cuma dekorasi.
        webView.addJavascriptInterface(new WebAppInterface(), "Android");

        // Konten website hasil upload (workflow menaruhnya di assets/www/)
        webView.loadUrl("file:///android_asset/www/index.html");
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.menu_main, menu);
        // Menu "Kelola PIN Pengguna" hanya tampak untuk admin
        MenuItem kelolaPin = menu.findItem(R.id.menu_kelola_pin);
        kelolaPin.setVisible(MODE_ADMIN.equals(mode));
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        int id = item.getItemId();
        if (id == R.id.menu_kelola_pin) {
            startActivity(new Intent(this, AdminActivity.class));
            return true;
        } else if (id == R.id.menu_keluar) {
            keluarKePinScreen();
            return true;
        }
        return super.onOptionsItemSelected(item);
    }

    @Override
    public void onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }

    private void keluarKePinScreen() {
        Intent intent = new Intent(this, PinActivity.class);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        startActivity(intent);
        finish();
    }

    // ------------------------------------------------------------------
    // Alur nyata "Konversi": pengguna pilih file project (html/zip/dll)
    // dari penyimpanan HP -> disalin ke cache -> dibagikan (share) ke
    // Admin/WhatsApp/Drive/aplikasi GitHub, dengan pesan yang menjelaskan
    // langkah selanjutnya (upload sebagai incoming/website.zip lalu
    // jalankan workflow GitHub Actions). RataAPK versi ini TIDAK
    // meng-compile APK langsung di dalam HP (butuh Android SDK & Gradle
    // yang berjalan di server/CI, bukan di WebView), jadi tahap build
    // sesungguhnya tetap lewat GitHub Actions seperti dijelaskan di tab
    // "Bantuan" pada dashboard.
    // ------------------------------------------------------------------
    private void mulaiPilihFile(String labelJenis) {
        modeBuildOtomatisAktif = false;
        labelJenisAktif = labelJenis;
        pemilihFile.launch(new String[]{"*/*"});
    }

    private void prosesFileTerpilih(Uri uriSumber, String labelJenis) {
        new Thread(() -> {
            try {
                File tujuan = salinKeCache(uriSumber);
                runOnUiThread(() -> bagikanFile(tujuan, labelJenis));
            } catch (IOException e) {
                runOnUiThread(() ->
                        Toast.makeText(this, "Gagal membaca file: " + e.getMessage(), Toast.LENGTH_LONG).show());
            }
        }).start();
    }

    // ------------------------------------------------------------------
    // Alur "Build Otomatis": pilih file -> unggah ke repo GitHub lewat API
    // -> picu workflow_dispatch -> pantau sampai selesai -> unduh & pasang
    // APK-nya. Butuh GitHubSettings sudah dikonfigurasi lebih dulu lewat
    // Panel Admin > Pengaturan GitHub.
    // ------------------------------------------------------------------
    private void mulaiBuildOtomatis(String labelJenis) {
        GitHubSettings settings = new GitHubSettings(this);
        if (!settings.sudahDikonfigurasi()) {
            new android.app.AlertDialog.Builder(this)
                    .setTitle("Belum Dikonfigurasi")
                    .setMessage("Build Otomatis butuh data repo GitHub diisi dulu (khusus Admin). Buka Panel Admin \u2192 Pengaturan GitHub, atau pakai \u201cBagikan Manual\u201d untuk sekarang.")
                    .setPositiveButton("OK", null)
                    .show();
            return;
        }
        modeBuildOtomatisAktif = true;
        labelJenisAktif = labelJenis;
        pemilihFile.launch(new String[]{"*/*"});
    }

    private void prosesFileUntukBuildOtomatis(Uri uriSumber, String labelJenis) {
        new Thread(() -> {
            try {
                File tujuan = salinKeCache(uriSumber);
                runOnUiThread(() -> {
                    Intent intent = new Intent(this, BuildProgressActivity.class);
                    intent.putExtra(BuildProgressActivity.EXTRA_FILE_PATH, tujuan.getAbsolutePath());
                    intent.putExtra(BuildProgressActivity.EXTRA_LABEL, labelJenis);
                    startActivity(intent);
                });
            } catch (IOException e) {
                runOnUiThread(() ->
                        Toast.makeText(this, "Gagal membaca file: " + e.getMessage(), Toast.LENGTH_LONG).show());
            }
        }).start();
    }

    private File salinKeCache(Uri uri) throws IOException {
        ContentResolver resolver = getContentResolver();
        String namaFile = ambilNamaFile(uri, resolver);

        File folder = new File(getCacheDir(), "project_upload");
        if (!folder.exists() && !folder.mkdirs()) {
            throw new IOException("Tidak bisa membuat folder cache");
        }
        File tujuan = new File(folder, namaFile);

        try (InputStream in = resolver.openInputStream(uri);
             OutputStream out = new FileOutputStream(tujuan)) {
            if (in == null) throw new IOException("File tidak bisa dibuka");
            byte[] buffer = new byte[8192];
            int dibaca;
            while ((dibaca = in.read(buffer)) != -1) {
                out.write(buffer, 0, dibaca);
            }
        }
        return tujuan;
    }

    private String ambilNamaFile(Uri uri, ContentResolver resolver) {
        String nama = "project_rataapk";
        try (Cursor cursor = resolver.query(uri, null, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                int idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if (idx != -1) {
                    String hasil = cursor.getString(idx);
                    if (hasil != null && !hasil.trim().isEmpty()) nama = hasil;
                }
            }
        } catch (Exception ignored) {
            // biarkan pakai nama default kalau query nama file gagal
        }
        return nama;
    }

    private void bagikanFile(File file, String labelJenis) {
        Uri uriContent = FileProvider.getUriForFile(
                this, getApplicationContext().getPackageName() + ".fileprovider", file);

        String ekstensi = MimeTypeMap.getFileExtensionFromUrl(file.getName());
        String mime = ekstensi != null
                ? MimeTypeMap.getSingleton().getMimeTypeFromExtension(ekstensi.toLowerCase())
                : null;
        if (mime == null) mime = "application/octet-stream";

        String pesan = "Project \"" + labelJenis + "\" dari RataAPK: " + file.getName()
                + "\n\nLangkah selanjutnya: unggah file ini sebagai incoming/website.zip "
                + "di repo GitHub Anda, lalu jalankan workflow \"Build RataAPK (Android & iOS)\" "
                + "untuk menghasilkan APK/IPA. Atau kirim file ini ke Admin lewat WhatsApp "
                + "0853-4652-7481 kalau ingin dibantu build-kan.";

        Intent share = new Intent(Intent.ACTION_SEND);
        share.setType(mime);
        share.putExtra(Intent.EXTRA_STREAM, uriContent);
        share.putExtra(Intent.EXTRA_TEXT, pesan);
        share.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);

        startActivity(Intent.createChooser(share, "Bagikan project \u201c" + labelJenis + "\u201d"));
    }

    private void salinTeksKeClipboard(String teks) {
        ClipboardManager cm = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        cm.setPrimaryClip(ClipData.newPlainText("RataAPK", teks));
        Toast.makeText(this, "Disalin ke clipboard", Toast.LENGTH_SHORT).show();
    }

    /** Jembatan yang dipanggil dari JavaScript di dashboard (assets/www/index.html). */
    private class WebAppInterface {

        @JavascriptInterface
        public void pilihDanBagikanFile(String labelJenis) {
            runOnUiThread(() -> mulaiPilihFile(labelJenis));
        }

        @JavascriptInterface
        public void bangunOtomatis(String labelJenis) {
            runOnUiThread(() -> mulaiBuildOtomatis(labelJenis));
        }

        @JavascriptInterface
        public boolean githubTerkonfigurasi() {
            return new GitHubSettings(MainActivity.this).sudahDikonfigurasi();
        }

        @JavascriptInterface
        public void salinTeks(String teks) {
            runOnUiThread(() -> salinTeksKeClipboard(teks));
        }

        @JavascriptInterface
        public boolean tersedia() {
            return true;
        }
    }
}
