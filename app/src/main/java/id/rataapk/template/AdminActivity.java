package id.rataapk.template;

import android.app.AlertDialog;
import android.content.Intent;
import android.os.Bundle;
import android.text.TextUtils;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ListView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.Toolbar;

import java.util.ArrayList;
import java.util.List;

/**
 * Panel khusus admin (hanya bisa dibuka dengan PIN admin 987871 dari
 * PinActivity). Di sini admin bisa menambah / menghapus PIN pengguna
 * biasa ("mode pengguna"), lalu membagikan PIN itu ke pengguna terkait
 * (misal lewat chat WhatsApp) supaya mereka bisa masuk ke aplikasi.
 */
public class AdminActivity extends AppCompatActivity {

    private PrefsHelper prefsHelper;
    private ListView lvPinPengguna;
    private ArrayAdapter<String> adapter;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_admin);

        prefsHelper = new PrefsHelper(this);

        Toolbar toolbar = findViewById(R.id.toolbarAdmin);
        setSupportActionBar(toolbar);

        EditText etPinBaru = findViewById(R.id.etPinBaru);
        Button btnTambahPin = findViewById(R.id.btnTambahPin);
        Button btnBukaAplikasi = findViewById(R.id.btnBukaAplikasi);
        Button btnPengaturanGitHub = findViewById(R.id.btnPengaturanGitHub);
        Button btnKeluar = findViewById(R.id.btnKeluar);
        lvPinPengguna = findViewById(R.id.lvPinPengguna);

        adapter = new ArrayAdapter<>(this, android.R.layout.simple_list_item_1, new ArrayList<>());
        lvPinPengguna.setAdapter(adapter);
        muatDaftarPin();

        btnTambahPin.setOnClickListener(v -> {
            String pinBaru = etPinBaru.getText().toString().trim();
            tambahPin(pinBaru);
            etPinBaru.setText("");
        });

        lvPinPengguna.setOnItemClickListener((parent, view, position, id) -> {
            String pin = adapter.getItem(position);
            if (pin != null) konfirmasiHapusPin(pin);
        });

        btnBukaAplikasi.setOnClickListener(v -> {
            Intent intent = new Intent(this, MainActivity.class);
            intent.putExtra(MainActivity.EXTRA_MODE, MainActivity.MODE_ADMIN);
            startActivity(intent);
        });

        btnPengaturanGitHub.setOnClickListener(v ->
                startActivity(new Intent(this, SettingsActivity.class)));

        btnKeluar.setOnClickListener(v -> keluarKePinScreen());
    }

    private void tambahPin(String pin) {
        if (TextUtils.isEmpty(pin) || pin.length() < 4 || pin.length() > 8 || !pin.matches("\\d+")) {
            Toast.makeText(this, R.string.admin_pin_invalid, Toast.LENGTH_SHORT).show();
            return;
        }
        if (prefsHelper.isAdminPin(pin)) {
            Toast.makeText(this, R.string.admin_pin_tidak_boleh_sama_admin, Toast.LENGTH_SHORT).show();
            return;
        }
        boolean sukses = prefsHelper.addUserPin(pin);
        if (!sukses) {
            Toast.makeText(this, R.string.admin_pin_sudah_ada, Toast.LENGTH_SHORT).show();
            return;
        }
        muatDaftarPin();
    }

    private void konfirmasiHapusPin(String pin) {
        new AlertDialog.Builder(this)
                .setTitle(R.string.admin_hapus_pin_judul)
                .setMessage(getString(R.string.admin_hapus_pin_pesan, pin))
                .setPositiveButton(R.string.admin_hapus_ya, (dialog, which) -> {
                    prefsHelper.removeUserPin(pin);
                    muatDaftarPin();
                })
                .setNegativeButton(R.string.admin_batal, null)
                .show();
    }

    private void muatDaftarPin() {
        List<String> daftar = new ArrayList<>(prefsHelper.getUserPins());
        adapter.clear();
        if (daftar.isEmpty()) {
            adapter.add(getString(R.string.admin_pin_kosong));
        } else {
            adapter.addAll(daftar);
        }
        adapter.notifyDataSetChanged();
    }

    private void keluarKePinScreen() {
        Intent intent = new Intent(this, PinActivity.class);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        startActivity(intent);
        finish();
    }
}
