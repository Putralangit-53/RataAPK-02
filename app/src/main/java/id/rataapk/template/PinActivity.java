package id.rataapk.template;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.text.TextUtils;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

public class PinActivity extends AppCompatActivity {

    /**
     * Nomor WhatsApp admin untuk tombol "Hubungi Admin" saat pengguna
     * belum punya / lupa PIN. GANTI dengan nomor admin Anda sendiri,
     * format internasional tanpa "+" dan tanpa spasi, contoh: 6285346527481
     */
    private static final String NOMOR_WA_ADMIN = "6285346527481";

    private PrefsHelper prefsHelper;
    private EditText etPin;
    private TextView tvPinError;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_pin);

        prefsHelper = new PrefsHelper(this);
        etPin = findViewById(R.id.etPin);
        tvPinError = findViewById(R.id.tvPinError);
        Button btnMasuk = findViewById(R.id.btnMasuk);
        TextView tvHubungiAdmin = findViewById(R.id.tvHubungiAdmin);

        btnMasuk.setOnClickListener(v -> coba());
        tvHubungiAdmin.setOnClickListener(v -> hubungiAdminViaWhatsApp());
    }

    private void coba() {
        String pin = etPin.getText().toString().trim();

        if (TextUtils.isEmpty(pin)) {
            tampilkanError();
            return;
        }

        if (prefsHelper.isAdminPin(pin)) {
            // PIN admin -> buka Panel Admin (mode admin)
            tvPinError.setVisibility(View.INVISIBLE);
            startActivity(new Intent(this, AdminActivity.class));
            etPin.setText("");
            return;
        }

        if (prefsHelper.isValidUserPin(pin)) {
            // PIN pengguna biasa -> langsung ke WebView (mode pengguna)
            tvPinError.setVisibility(View.INVISIBLE);
            Intent intent = new Intent(this, MainActivity.class);
            intent.putExtra(MainActivity.EXTRA_MODE, MainActivity.MODE_USER);
            startActivity(intent);
            etPin.setText("");
            return;
        }

        tampilkanError();
    }

    private void tampilkanError() {
        tvPinError.setVisibility(View.VISIBLE);
        Toast.makeText(this, R.string.pin_salah, Toast.LENGTH_SHORT).show();
    }

    private void hubungiAdminViaWhatsApp() {
        String pesan = getString(R.string.pin_hubungi_admin_pesan);
        Uri uri = Uri.parse("https://wa.me/" + NOMOR_WA_ADMIN
                + "?text=" + Uri.encode(pesan));
        Intent intent = new Intent(Intent.ACTION_VIEW, uri);
        try {
            startActivity(intent);
        } catch (Exception e) {
            Toast.makeText(this, "WhatsApp tidak ditemukan di perangkat ini.", Toast.LENGTH_SHORT).show();
        }
    }
}
