package id.rataapk.template;

import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.view.View;
import android.widget.Button;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.TextView;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.FileProvider;

import java.io.File;
import java.text.SimpleDateFormat;
import java.util.Locale;

/**
 * Menjalankan alur "Build Otomatis" (unggah -> picu workflow -> pantau ->
 * unduh APK) di background thread, sambil menampilkan log berjalan ke
 * pengguna. Kalau sukses, menawarkan tombol "Pasang APK" langsung.
 *
 * Dibuka dari MainActivity.WebAppInterface.bangunOtomatis(), yang mengirim
 * path file project (hasil disalin ke cache) dan label jenis konversi lewat
 * extra Intent EXTRA_FILE_PATH / EXTRA_LABEL.
 */
public class BuildProgressActivity extends AppCompatActivity {

    public static final String EXTRA_FILE_PATH = "extra_file_path";
    public static final String EXTRA_LABEL = "extra_label";

    private TextView tvLog;
    private ScrollView scrollLog;
    private ProgressBar progressBar;
    private Button btnAksi;
    private TextView tvStatus;

    private File apkHasil;
    private volatile boolean sedangBerjalan = true;

    private final SimpleDateFormat jamFormat = new SimpleDateFormat("HH:mm:ss", Locale.getDefault());

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_build_progress);
        setTitle(R.string.build_progress_judul);

        tvLog = findViewById(R.id.tvLog);
        scrollLog = findViewById(R.id.scrollLog);
        progressBar = findViewById(R.id.progressBar);
        btnAksi = findViewById(R.id.btnAksi);
        tvStatus = findViewById(R.id.tvStatus);

        btnAksi.setVisibility(View.GONE);
        btnAksi.setOnClickListener(v -> {
            if (apkHasil != null) {
                pasangApk(apkHasil);
            } else {
                finish();
            }
        });

        String pathFile = getIntent().getStringExtra(EXTRA_FILE_PATH);
        String label = getIntent().getStringExtra(EXTRA_LABEL);
        if (pathFile == null) {
            tulisLog("Tidak ada file yang dipilih.");
            gagalkan("Tidak ada file untuk diproses.");
            return;
        }

        jalankanBuild(new File(pathFile), label != null ? label : "Project");
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        sedangBerjalan = false;
    }

    private void jalankanBuild(File file, String label) {
        GitHubSettings settings = new GitHubSettings(this);
        String owner = settings.getOwner();
        String repo = settings.getRepo();
        String token = settings.getToken();
        String branch = settings.getBranch();
        String workflowFile = settings.getWorkflowFile();
        String appLabel = settings.getAppLabel();
        String packageName = settings.getPackageName();

        GitHubBuildManager manager = new GitHubBuildManager(owner, repo, token, branch, workflowFile);
        GitHubBuildManager.ProgressListener listener = pesan -> runOnUiThread(() -> {
            tulisLog(pesan);
            tvStatus.setText(pesan);
        });

        new Thread(() -> {
            try {
                String namaFile = file.getName().toLowerCase();
                String pathTujuan = namaFile.endsWith(".zip")
                        ? "incoming/website.zip"
                        : "incoming/" + file.getName();

                manager.unggahFile(file, pathTujuan, listener);
                if (!sedangBerjalan) return;

                long waktuPicu = manager.picuWorkflow(appLabel, packageName, listener);
                if (!sedangBerjalan) return;

                long runId = manager.cariRunTerbaru(waktuPicu, listener);
                if (!sedangBerjalan) return;

                GitHubBuildManager.HasilRun hasil = manager.pantauSampaiSelesai(runId, listener);
                if (!sedangBerjalan) return;

                if (!"success".equals(hasil.conclusion)) {
                    runOnUiThread(() -> gagalkan(
                            "Build selesai tapi gagal (" + hasil.conclusion + "). "
                                    + "Cek log lengkapnya di: " + hasil.htmlUrl));
                    return;
                }

                File folderUnduhan = new File(getCacheDir(), "build_result");
                File apk = manager.unduhDanEkstrakApk(runId, folderUnduhan, listener);
                if (!sedangBerjalan) return;

                apkHasil = apk;
                runOnUiThread(() -> selesaiDenganSukses(apk));

            } catch (GitHubBuildManager.BuildException e) {
                runOnUiThread(() -> gagalkan(e.getMessage()));
            } catch (Exception e) {
                runOnUiThread(() -> gagalkan("Terjadi kesalahan tak terduga: " + e.getMessage()));
            }
        }).start();
    }

    private void tulisLog(String pesan) {
        String waktu = jamFormat.format(new java.util.Date());
        tvLog.append("[" + waktu + "] " + pesan + "\n");
        scrollLog.post(() -> scrollLog.fullScroll(View.FOCUS_DOWN));
    }

    private void selesaiDenganSukses(File apk) {
        progressBar.setVisibility(View.GONE);
        tvStatus.setText(getString(R.string.build_progress_sukses));
        tulisLog("Build berhasil! APK: " + apk.getName() + " (" + (apk.length() / 1024) + " KB)");
        btnAksi.setText(R.string.build_progress_pasang_apk);
        btnAksi.setVisibility(View.VISIBLE);
    }

    private void gagalkan(String pesanError) {
        progressBar.setVisibility(View.GONE);
        tvStatus.setText(getString(R.string.build_progress_gagal));
        tulisLog("GAGAL: " + pesanError);
        btnAksi.setText(R.string.build_progress_tutup);
        btnAksi.setVisibility(View.VISIBLE);
    }

    private void pasangApk(File apk) {
        // Sejak Android 8 (API 26), memasang APK dari luar Play Store butuh
        // izin "Pasang aplikasi tak dikenal" yang harus disetujui manual
        // oleh pengguna lewat halaman Pengaturan sistem.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !getPackageManager().canRequestPackageInstalls()) {
            tulisLog("Meminta izin \u201cPasang aplikasi tak dikenal\u201d...");
            Intent intent = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:" + getPackageName()));
            startActivity(intent);
            return;
        }

        Uri uriApk = FileProvider.getUriForFile(
                this, getApplicationContext().getPackageName() + ".fileprovider", apk);

        Intent intent = new Intent(Intent.ACTION_VIEW);
        intent.setDataAndType(uriApk, "application/vnd.android.package-archive");
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        startActivity(intent);
    }
}
