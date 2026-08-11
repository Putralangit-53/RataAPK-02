package id.rataapk.template;

import android.content.Context;
import android.content.SharedPreferences;
import android.text.TextUtils;

/**
 * Menyimpan konfigurasi GitHub yang dipakai alur "Build Otomatis":
 * repo tujuan, branch, nama file workflow, dan Personal Access Token (PAT).
 *
 * CATATAN KEAMANAN: token disimpan di SharedPreferences biasa (bukan
 * terenkripsi) langsung di penyimpanan aplikasi ini. Ini AMAN dari aplikasi
 * lain selama HP tidak di-root, tapi TIDAK terenkripsi kalau HP dicuri/hilang
 * dan berhasil di-root. Sangat disarankan:
 *   - Pakai "Fine-grained personal access token" (bukan classic token),
 *     dibatasi HANYA ke satu repo ini saja.
 *   - Beri izin token itu HANYA "Contents: Read & write" dan
 *     "Actions: Read & write" — jangan beri izin lain.
 *   - Set masa berlaku token (expiration), jangan pilih "No expiration".
 *   - Cabut (revoke) token dari GitHub kalau HP hilang.
 */
public class GitHubSettings {

    private static final String PREF_NAME = "rataapk_github_settings";
    private static final String KEY_OWNER = "owner";
    private static final String KEY_REPO = "repo";
    private static final String KEY_TOKEN = "token";
    private static final String KEY_BRANCH = "branch";
    private static final String KEY_WORKFLOW_FILE = "workflow_file";
    private static final String KEY_APP_LABEL = "app_label";
    private static final String KEY_PACKAGE_NAME = "package_name";

    private final SharedPreferences prefs;

    public GitHubSettings(Context context) {
        prefs = context.getApplicationContext().getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
    }

    public String getOwner() { return prefs.getString(KEY_OWNER, ""); }
    public String getRepo() { return prefs.getString(KEY_REPO, ""); }
    public String getToken() { return prefs.getString(KEY_TOKEN, ""); }
    public String getBranch() {
        String b = prefs.getString(KEY_BRANCH, "");
        return TextUtils.isEmpty(b) ? "main" : b;
    }
    public String getWorkflowFile() {
        String w = prefs.getString(KEY_WORKFLOW_FILE, "");
        return TextUtils.isEmpty(w) ? "build-apps.yml" : w;
    }
    public String getAppLabel() {
        String a = prefs.getString(KEY_APP_LABEL, "");
        return TextUtils.isEmpty(a) ? "RataAPK" : a;
    }
    public String getPackageName() {
        String p = prefs.getString(KEY_PACKAGE_NAME, "");
        return TextUtils.isEmpty(p) ? "id.rataapk.template" : p;
    }

    /** true kalau owner, repo, dan token sudah diisi (syarat minimum build otomatis). */
    public boolean sudahDikonfigurasi() {
        return !TextUtils.isEmpty(getOwner()) && !TextUtils.isEmpty(getRepo()) && !TextUtils.isEmpty(getToken());
    }

    public void simpan(String owner, String repo, String token, String branch,
                        String workflowFile, String appLabel, String packageName) {
        prefs.edit()
                .putString(KEY_OWNER, owner == null ? "" : owner.trim())
                .putString(KEY_REPO, repo == null ? "" : repo.trim())
                .putString(KEY_TOKEN, token == null ? "" : token.trim())
                .putString(KEY_BRANCH, branch == null ? "" : branch.trim())
                .putString(KEY_WORKFLOW_FILE, workflowFile == null ? "" : workflowFile.trim())
                .putString(KEY_APP_LABEL, appLabel == null ? "" : appLabel.trim())
                .putString(KEY_PACKAGE_NAME, packageName == null ? "" : packageName.trim())
                .apply();
    }

    public void hapusToken() {
        prefs.edit().remove(KEY_TOKEN).apply();
    }
}
