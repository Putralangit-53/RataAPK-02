package id.rataapk.template;

import android.util.Base64;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * Menjalankan alur "Build Otomatis" lewat GitHub REST API:
 *   1) unggah file project ke repo (Contents API)
 *   2) picu workflow_dispatch
 *   3) cari run yang baru saja terpicu, lalu pantau statusnya
 *   4) kalau sukses, unduh artifact APK hasil build & ekstrak
 *
 * PENTING: semua method di sini melakukan panggilan jaringan (blocking),
 * WAJIB dipanggil dari background thread, TIDAK BOLEH dari main thread.
 * Dipakai oleh BuildProgressActivity.
 */
public class GitHubBuildManager {

    public interface ProgressListener {
        void onProgress(String pesan);
    }

    public static class BuildException extends Exception {
        public BuildException(String message) { super(message); }
        public BuildException(String message, Throwable cause) { super(message, cause); }
    }

    private final String owner;
    private final String repo;
    private final String token;
    private final String branch;
    private final String workflowFile;

    public GitHubBuildManager(String owner, String repo, String token, String branch, String workflowFile) {
        this.owner = owner;
        this.repo = repo;
        this.token = token;
        this.branch = branch;
        this.workflowFile = workflowFile;
    }

    private String apiBase() {
        return "https://api.github.com/repos/" + owner + "/" + repo;
    }

    private HttpURLConnection bukaKoneksi(String urlStr, String method) throws IOException {
        URL url = new URL(urlStr);
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod(method);
        conn.setRequestProperty("Authorization", "Bearer " + token);
        conn.setRequestProperty("Accept", "application/vnd.github+json");
        conn.setRequestProperty("X-GitHub-Api-Version", "2022-11-28");
        conn.setConnectTimeout(15000);
        conn.setReadTimeout(30000);
        return conn;
    }

    private String bacaSemua(InputStream in) throws IOException {
        if (in == null) return "";
        ByteArrayOutputStream bos = new ByteArrayOutputStream();
        byte[] buf = new byte[4096];
        int n;
        while ((n = in.read(buf)) != -1) bos.write(buf, 0, n);
        return bos.toString("UTF-8");
    }

    private String ringkas(String teks) {
        if (teks == null) return "";
        return teks.length() > 300 ? teks.substring(0, 300) + "..." : teks;
    }

    private byte[] bacaFileBytes(File file) throws IOException {
        ByteArrayOutputStream bos = new ByteArrayOutputStream();
        try (InputStream in = new java.io.FileInputStream(file)) {
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) != -1) bos.write(buf, 0, n);
        }
        return bos.toByteArray();
    }

    // ------------------------------------------------------------------
    // 1) Unggah file project ke repo lewat Contents API
    // ------------------------------------------------------------------
    public void unggahFile(File file, String pathTujuan, ProgressListener listener) throws BuildException {
        try {
            listener.onProgress("Membaca file \u201c" + file.getName() + "\u201d...");
            byte[] isi = bacaFileBytes(file);
            if (isi.length > 60 * 1024 * 1024) {
                throw new BuildException("File terlalu besar (maks sekitar 60MB lewat alur otomatis). Gunakan opsi \u201cBagikan Manual\u201d untuk file besar.");
            }
            String base64Isi = Base64.encodeToString(isi, Base64.NO_WRAP);

            listener.onProgress("Mengunggah ke GitHub (" + pathTujuan + ")...");

            // Cek dulu apakah file itu sudah ada di repo (kalau ada, GitHub
            // mewajibkan kita menyertakan SHA versi lama untuk menimpanya)
            String shaLama = null;
            HttpURLConnection cekConn = bukaKoneksi(
                    apiBase() + "/contents/" + pathTujuan + "?ref=" + branch, "GET");
            int cekCode = cekConn.getResponseCode();
            if (cekCode == 200) {
                String body = bacaSemua(cekConn.getInputStream());
                shaLama = new JSONObject(body).optString("sha", null);
            }
            cekConn.disconnect();

            JSONObject payload = new JSONObject();
            payload.put("message", "RataAPK: unggah project dari aplikasi Android (" + file.getName() + ")");
            payload.put("content", base64Isi);
            payload.put("branch", branch);
            if (shaLama != null) payload.put("sha", shaLama);

            HttpURLConnection conn = bukaKoneksi(apiBase() + "/contents/" + pathTujuan, "PUT");
            conn.setDoOutput(true);
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8");
            try (OutputStream os = conn.getOutputStream()) {
                os.write(payload.toString().getBytes(StandardCharsets.UTF_8));
            }
            int code = conn.getResponseCode();
            if (code != 200 && code != 201) {
                String err = bacaSemua(conn.getErrorStream());
                conn.disconnect();
                throw new BuildException(pesanKesalahanHttp(code, err));
            }
            conn.disconnect();
        } catch (JSONException e) {
            throw new BuildException("Gagal menyusun data unggahan: " + e.getMessage(), e);
        } catch (IOException e) {
            throw new BuildException("Gagal menghubungi GitHub: " + e.getMessage(), e);
        }
    }

    // ------------------------------------------------------------------
    // 2) Picu workflow_dispatch
    // ------------------------------------------------------------------
    public long picuWorkflow(String appLabel, String packageName, ProgressListener listener) throws BuildException {
        long waktuPicu = System.currentTimeMillis();
        try {
            listener.onProgress("Menjalankan workflow GitHub Actions...");
            JSONObject inputs = new JSONObject();
            inputs.put("app_label", appLabel);
            inputs.put("package_name", packageName);
            inputs.put("build_android", "true");
            inputs.put("build_ios", "false");

            JSONObject payload = new JSONObject();
            payload.put("ref", branch);
            payload.put("inputs", inputs);

            HttpURLConnection conn = bukaKoneksi(
                    apiBase() + "/actions/workflows/" + workflowFile + "/dispatches", "POST");
            conn.setDoOutput(true);
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8");
            try (OutputStream os = conn.getOutputStream()) {
                os.write(payload.toString().getBytes(StandardCharsets.UTF_8));
            }
            int code = conn.getResponseCode();
            if (code != 204) {
                String err = bacaSemua(conn.getErrorStream());
                conn.disconnect();
                throw new BuildException(pesanKesalahanHttp(code, err));
            }
            conn.disconnect();
            return waktuPicu;
        } catch (JSONException e) {
            throw new BuildException("Gagal menyusun perintah workflow: " + e.getMessage(), e);
        } catch (IOException e) {
            throw new BuildException("Gagal memicu workflow: " + e.getMessage(), e);
        }
    }

    // ------------------------------------------------------------------
    // 3) Cari run yang baru saja terpicu (dengan retry, karena GitHub
    //    butuh beberapa detik sebelum run baru muncul di daftar)
    // ------------------------------------------------------------------
    public long cariRunTerbaru(long waktuPicu, ProgressListener listener) throws BuildException {
        listener.onProgress("Mencari proses build yang baru dimulai...");
        try {
            for (int percobaan = 0; percobaan < 10; percobaan++) {
                HttpURLConnection conn = bukaKoneksi(
                        apiBase() + "/actions/workflows/" + workflowFile
                                + "/runs?event=workflow_dispatch&branch=" + branch + "&per_page=5",
                        "GET");
                int code = conn.getResponseCode();
                if (code == 200) {
                    String body = bacaSemua(conn.getInputStream());
                    conn.disconnect();
                    JSONObject hasil = new JSONObject(body);
                    JSONArray runs = hasil.optJSONArray("workflow_runs");
                    if (runs != null) {
                        for (int i = 0; i < runs.length(); i++) {
                            JSONObject run = runs.getJSONObject(i);
                            String createdAt = run.optString("created_at", null);
                            long dibuatMillis = parseIso8601(createdAt);
                            // beri toleransi 20 detik untuk perbedaan jam antara HP & server
                            if (dibuatMillis >= waktuPicu - 20000) {
                                return run.getLong("id");
                            }
                        }
                    }
                } else {
                    conn.disconnect();
                }
                sleep(3000);
            }
            throw new BuildException("Proses build tidak ditemukan setelah menunggu. Cek langsung tab Actions di GitHub repo Anda.");
        } catch (JSONException e) {
            throw new BuildException("Gagal membaca daftar proses build: " + e.getMessage(), e);
        } catch (IOException e) {
            throw new BuildException("Gagal menghubungi GitHub: " + e.getMessage(), e);
        }
    }

    // ------------------------------------------------------------------
    // 4) Pantau status run sampai selesai
    // ------------------------------------------------------------------
    public static class HasilRun {
        public final String status;
        public final String conclusion;
        public final String htmlUrl;
        HasilRun(String status, String conclusion, String htmlUrl) {
            this.status = status;
            this.conclusion = conclusion;
            this.htmlUrl = htmlUrl;
        }
    }

    public HasilRun pantauSampaiSelesai(long runId, ProgressListener listener) throws BuildException {
        try {
            int detikBerlalu = 0;
            while (true) {
                HttpURLConnection conn = bukaKoneksi(apiBase() + "/actions/runs/" + runId, "GET");
                int code = conn.getResponseCode();
                if (code != 200) {
                    String err = bacaSemua(conn.getErrorStream());
                    conn.disconnect();
                    throw new BuildException(pesanKesalahanHttp(code, err));
                }
                String body = bacaSemua(conn.getInputStream());
                conn.disconnect();

                JSONObject run = new JSONObject(body);
                String status = run.optString("status", "unknown");
                String conclusion = run.isNull("conclusion") ? null : run.optString("conclusion", null);
                String htmlUrl = run.optString("html_url", "");

                if ("completed".equals(status)) {
                    return new HasilRun(status, conclusion, htmlUrl);
                }

                listener.onProgress("Sedang build di GitHub Actions (" + status + ")... " + detikBerlalu + "s");
                sleep(6000);
                detikBerlalu += 6;

                if (detikBerlalu > 20 * 60) {
                    throw new BuildException("Build belum selesai setelah 20 menit. Cek langsung di: " + htmlUrl);
                }
            }
        } catch (JSONException e) {
            throw new BuildException("Gagal membaca status build: " + e.getMessage(), e);
        } catch (IOException e) {
            throw new BuildException("Gagal menghubungi GitHub: " + e.getMessage(), e);
        }
    }

    // ------------------------------------------------------------------
    // 5) Unduh artifact APK hasil build & ekstrak
    // ------------------------------------------------------------------
    public File unduhDanEkstrakApk(long runId, File folderTujuan, ProgressListener listener) throws BuildException {
        try {
            listener.onProgress("Mencari hasil build (artifact)...");
            HttpURLConnection listConn = bukaKoneksi(apiBase() + "/actions/runs/" + runId + "/artifacts", "GET");
            int listCode = listConn.getResponseCode();
            if (listCode != 200) {
                String err = bacaSemua(listConn.getErrorStream());
                listConn.disconnect();
                throw new BuildException(pesanKesalahanHttp(listCode, err));
            }
            String listBody = bacaSemua(listConn.getInputStream());
            listConn.disconnect();

            JSONObject hasil = new JSONObject(listBody);
            JSONArray artifacts = hasil.optJSONArray("artifacts");
            if (artifacts == null || artifacts.length() == 0) {
                throw new BuildException("Build selesai tapi tidak ada artifact APK yang ditemukan.");
            }

            long artifactId = -1;
            for (int i = 0; i < artifacts.length(); i++) {
                JSONObject a = artifacts.getJSONObject(i);
                if ("android-apk-result".equals(a.optString("name"))) {
                    artifactId = a.getLong("id");
                    break;
                }
            }
            if (artifactId == -1) {
                throw new BuildException("Artifact \u201candroid-apk-result\u201d tidak ditemukan di hasil build ini.");
            }

            listener.onProgress("Mengunduh APK...");
            if (!folderTujuan.exists() && !folderTujuan.mkdirs()) {
                throw new BuildException("Tidak bisa membuat folder unduhan.");
            }
            File zipFile = new File(folderTujuan, "hasil_build.zip");
            unduhKeFile(apiBase() + "/actions/artifacts/" + artifactId + "/zip", zipFile);

            listener.onProgress("Mengekstrak APK...");
            File apk = ekstrakApkDariZip(zipFile, folderTujuan);
            //noinspection ResultOfMethodCallIgnored
            zipFile.delete();
            if (apk == null) {
                throw new BuildException("File .apk tidak ditemukan di dalam artifact hasil build.");
            }
            return apk;
        } catch (JSONException e) {
            throw new BuildException("Gagal membaca daftar artifact: " + e.getMessage(), e);
        } catch (IOException e) {
            throw new BuildException("Gagal mengunduh hasil build: " + e.getMessage(), e);
        }
    }

    /** Unduh URL (dengan otorisasi) ke file, mengikuti redirect manual kalau perlu. */
    private void unduhKeFile(String urlAwal, File tujuan) throws IOException, BuildException {
        String urlSaatIni = urlAwal;
        boolean pakaiAuth = true;

        for (int lompat = 0; lompat < 5; lompat++) {
            HttpURLConnection conn = (HttpURLConnection) new URL(urlSaatIni).openConnection();
            conn.setInstanceFollowRedirects(false);
            conn.setConnectTimeout(15000);
            conn.setReadTimeout(60000);
            if (pakaiAuth) {
                conn.setRequestProperty("Authorization", "Bearer " + token);
                conn.setRequestProperty("Accept", "application/vnd.github+json");
                conn.setRequestProperty("X-GitHub-Api-Version", "2022-11-28");
            }
            int code = conn.getResponseCode();

            if (code == 302 || code == 301 || code == 303) {
                String lokasi = conn.getHeaderField("Location");
                conn.disconnect();
                if (lokasi == null) throw new BuildException("Redirect tanpa alamat tujuan saat mengunduh artifact.");
                urlSaatIni = lokasi;
                // URL redirect dari GitHub sudah membawa tanda tangan otorisasinya
                // sendiri di query string, jadi header Authorization tidak dipakai lagi
                pakaiAuth = false;
                continue;
            }

            if (code != 200) {
                String err = bacaSemua(conn.getErrorStream());
                conn.disconnect();
                throw new BuildException(pesanKesalahanHttp(code, err));
            }

            try (InputStream in = conn.getInputStream();
                 OutputStream out = new FileOutputStream(tujuan)) {
                byte[] buf = new byte[8192];
                int n;
                while ((n = in.read(buf)) != -1) out.write(buf, 0, n);
            }
            conn.disconnect();
            return;
        }
        throw new BuildException("Terlalu banyak redirect saat mengunduh artifact.");
    }

    private File ekstrakApkDariZip(File zipFile, File folderTujuan) throws IOException {
        try (ZipInputStream zis = new ZipInputStream(new java.io.FileInputStream(zipFile))) {
            ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {
                if (!entry.isDirectory() && entry.getName().toLowerCase().endsWith(".apk")) {
                    String namaFile = new File(entry.getName()).getName();
                    File tujuan = new File(folderTujuan, namaFile);
                    try (OutputStream out = new FileOutputStream(tujuan)) {
                        byte[] buf = new byte[8192];
                        int n;
                        while ((n = zis.read(buf)) != -1) out.write(buf, 0, n);
                    }
                    return tujuan;
                }
            }
        }
        return null;
    }

    private String pesanKesalahanHttp(int code, String body) {
        String ringkasan = ringkas(body);
        if (code == 401) {
            return "Token GitHub tidak valid atau sudah kedaluwarsa (HTTP 401). Perbarui token di Pengaturan.";
        } else if (code == 403) {
            return "Token GitHub tidak punya izin yang cukup (HTTP 403). Pastikan token diberi izin \u201cContents: Read & write\u201d dan \u201cActions: Read & write\u201d. Detail: " + ringkasan;
        } else if (code == 404) {
            return "Repo/workflow tidak ditemukan (HTTP 404). Cek lagi nama owner/repo dan nama file workflow di Pengaturan.";
        }
        return "GitHub mengembalikan error (HTTP " + code + "): " + ringkasan;
    }

    private static long parseIso8601(String iso) {
        if (iso == null) return 0;
        try {
            java.text.SimpleDateFormat sdf = new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", java.util.Locale.US);
            sdf.setTimeZone(java.util.TimeZone.getTimeZone("UTC"));
            return sdf.parse(iso).getTime();
        } catch (Exception e) {
            return 0;
        }
    }

    private static void sleep(long ms) {
        try {
            Thread.sleep(ms);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
