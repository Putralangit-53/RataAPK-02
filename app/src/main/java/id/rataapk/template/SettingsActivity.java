package id.rataapk.template;

import android.os.Bundle;
import android.text.TextUtils;
import android.widget.EditText;
import android.widget.Toast;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.Toolbar;

/**
 * Layar khusus admin untuk mengisi konfigurasi repo GitHub yang dipakai
 * alur "Build Otomatis": owner/repo, branch, nama file workflow, Personal
 * Access Token, serta nama aplikasi & package name default.
 *
 * Dibuka dari AdminActivity.
 */
public class SettingsActivity extends AppCompatActivity {

    private EditText etOwner;
    private EditText etRepo;
    private EditText etToken;
    private EditText etBranch;
    private EditText etWorkflowFile;
    private EditText etAppLabel;
    private EditText etPackageName;

    private GitHubSettings settings;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_settings);

        Toolbar toolbar = findViewById(R.id.toolbarSettings);
        setSupportActionBar(toolbar);
        if (getSupportActionBar() != null) {
            getSupportActionBar().setDisplayHomeAsUpEnabled(true);
            getSupportActionBar().setTitle(R.string.settings_judul);
        }

        etOwner = findViewById(R.id.etOwner);
        etRepo = findViewById(R.id.etRepo);
        etToken = findViewById(R.id.etToken);
        etBranch = findViewById(R.id.etBranch);
        etWorkflowFile = findViewById(R.id.etWorkflowFile);
        etAppLabel = findViewById(R.id.etAppLabel);
        etPackageName = findViewById(R.id.etPackageName);

        settings = new GitHubSettings(this);
        muatDariPenyimpanan();

        findViewById(R.id.btnSimpanSettings).setOnClickListener(v -> simpan());
        findViewById(R.id.btnHapusToken).setOnClickListener(v -> {
            settings.hapusToken();
            etToken.setText("");
            Toast.makeText(this, R.string.settings_token_dihapus, Toast.LENGTH_SHORT).show();
        });
    }

    private void muatDariPenyimpanan() {
        etOwner.setText(settings.getOwner());
        etRepo.setText(settings.getRepo());
        etToken.setText(settings.getToken());
        etBranch.setText(settings.getBranch());
        etWorkflowFile.setText(settings.getWorkflowFile());
        etAppLabel.setText(settings.getAppLabel());
        etPackageName.setText(settings.getPackageName());
    }

    private void simpan() {
        String owner = etOwner.getText().toString().trim();
        String repo = etRepo.getText().toString().trim();
        String token = etToken.getText().toString().trim();

        if (TextUtils.isEmpty(owner) || TextUtils.isEmpty(repo) || TextUtils.isEmpty(token)) {
            Toast.makeText(this, R.string.settings_wajib_diisi, Toast.LENGTH_LONG).show();
            return;
        }

        settings.simpan(
                owner,
                repo,
                token,
                etBranch.getText().toString().trim(),
                etWorkflowFile.getText().toString().trim(),
                etAppLabel.getText().toString().trim(),
                etPackageName.getText().toString().trim()
        );
        Toast.makeText(this, R.string.settings_tersimpan, Toast.LENGTH_SHORT).show();
        finish();
    }

    @Override
    public boolean onSupportNavigateUp() {
        finish();
        return true;
    }
}
