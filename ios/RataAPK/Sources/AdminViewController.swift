import UIKit

/// Panel khusus admin (hanya bisa dibuka dengan PIN admin 987871 dari
/// PinViewController). Di sini admin bisa menambah / menghapus PIN
/// pengguna biasa ("mode pengguna"), lalu membagikan PIN itu ke pengguna
/// terkait (misal lewat chat WhatsApp) supaya mereka bisa masuk ke aplikasi.
class AdminViewController: UIViewController {

    private let bgColor = UIColor(red: 248.0 / 255.0, green: 250.0 / 255.0, blue: 252.0 / 255.0, alpha: 1)
    private let navyColor = UIColor(red: 6.0 / 255.0, green: 46.0 / 255.0, blue: 94.0 / 255.0, alpha: 1)
    private let accentColor = UIColor(red: 254.0 / 255.0, green: 168.0 / 255.0, blue: 1.0 / 255.0, alpha: 1)
    private let errorColor = UIColor(red: 211.0 / 255.0, green: 47.0 / 255.0, blue: 47.0 / 255.0, alpha: 1)

    private let badgeLabel = UILabel()
    private let bukaAplikasiButton = UIButton(type: .system)
    private let pengaturanGitHubButton = UIButton(type: .system)
    private let daftarPinTitleLabel = UILabel()
    private let pinBaruField = UITextField()
    private let tambahPinButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let keluarButton = UIButton(type: .system)
    private let footerLabel = UILabel()

    private var daftarPin: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Panel Admin"
        view.backgroundColor = bgColor
        navigationController?.setNavigationBarHidden(false, animated: false)
        setupViews()
        muatDaftarPin()
    }

    private func setupViews() {
        badgeLabel.text = "Mode Admin"
        badgeLabel.textColor = accentColor
        badgeLabel.font = .systemFont(ofSize: 14, weight: .bold)
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false

        bukaAplikasiButton.setTitle("Buka Aplikasi (Mode Admin)", for: .normal)
        bukaAplikasiButton.setTitleColor(.white, for: .normal)
        bukaAplikasiButton.backgroundColor = navyColor
        bukaAplikasiButton.layer.cornerRadius = 10
        bukaAplikasiButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        bukaAplikasiButton.addTarget(self, action: #selector(bukaAplikasiTapped), for: .touchUpInside)
        bukaAplikasiButton.translatesAutoresizingMaskIntoConstraints = false

        pengaturanGitHubButton.setTitle("\u{2699}\u{fe0f} Pengaturan GitHub (Build Otomatis)", for: .normal)
        pengaturanGitHubButton.setTitleColor(.darkText, for: .normal)
        pengaturanGitHubButton.backgroundColor = accentColor
        pengaturanGitHubButton.layer.cornerRadius = 10
        pengaturanGitHubButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        pengaturanGitHubButton.addTarget(self, action: #selector(pengaturanGitHubTapped), for: .touchUpInside)
        pengaturanGitHubButton.translatesAutoresizingMaskIntoConstraints = false

        let garis = UIView()
        garis.backgroundColor = UIColor(white: 0.87, alpha: 1)
        garis.translatesAutoresizingMaskIntoConstraints = false

        daftarPinTitleLabel.text = "Daftar PIN Pengguna"
        daftarPinTitleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        daftarPinTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        pinBaruField.placeholder = "PIN pengguna baru (4\u{2013}8 digit)"
        pinBaruField.borderStyle = .roundedRect
        pinBaruField.backgroundColor = .white
        pinBaruField.keyboardType = .numberPad
        pinBaruField.translatesAutoresizingMaskIntoConstraints = false

        tambahPinButton.setTitle("Tambah PIN", for: .normal)
        tambahPinButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        tambahPinButton.addTarget(self, action: #selector(tambahPinTapped), for: .touchUpInside)
        tambahPinButton.translatesAutoresizingMaskIntoConstraints = false

        let inputRow = UIStackView(arrangedSubviews: [pinBaruField, tambahPinButton])
        inputRow.axis = .horizontal
        inputRow.spacing = 8
        inputRow.alignment = .center
        inputRow.translatesAutoresizingMaskIntoConstraints = false

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .white
        tableView.layer.cornerRadius = 10
        tableView.layer.masksToBounds = true
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "pinCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false

        keluarButton.setTitle("Keluar", for: .normal)
        keluarButton.setTitleColor(.white, for: .normal)
        keluarButton.backgroundColor = errorColor
        keluarButton.layer.cornerRadius = 10
        keluarButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        keluarButton.addTarget(self, action: #selector(keluarTapped), for: .touchUpInside)
        keluarButton.translatesAutoresizingMaskIntoConstraints = false

        footerLabel.text = "@By Yusup -Putra Langit Technology 2026"
        footerLabel.font = .systemFont(ofSize: 10.5)
        footerLabel.textColor = .gray
        footerLabel.alpha = 0.7
        footerLabel.textAlignment = .center
        footerLabel.translatesAutoresizingMaskIntoConstraints = false

        [badgeLabel, bukaAplikasiButton, pengaturanGitHubButton, garis, daftarPinTitleLabel, inputRow, tableView, keluarButton, footerLabel].forEach {
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            badgeLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            badgeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            bukaAplikasiButton.topAnchor.constraint(equalTo: badgeLabel.bottomAnchor, constant: 12),
            bukaAplikasiButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            bukaAplikasiButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            bukaAplikasiButton.heightAnchor.constraint(equalToConstant: 48),

            pengaturanGitHubButton.topAnchor.constraint(equalTo: bukaAplikasiButton.bottomAnchor, constant: 8),
            pengaturanGitHubButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            pengaturanGitHubButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            pengaturanGitHubButton.heightAnchor.constraint(equalToConstant: 44),

            garis.topAnchor.constraint(equalTo: pengaturanGitHubButton.bottomAnchor, constant: 16),
            garis.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            garis.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            garis.heightAnchor.constraint(equalToConstant: 1),

            daftarPinTitleLabel.topAnchor.constraint(equalTo: garis.bottomAnchor, constant: 16),
            daftarPinTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            inputRow.topAnchor.constraint(equalTo: daftarPinTitleLabel.bottomAnchor, constant: 10),
            inputRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            inputRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            pinBaruField.heightAnchor.constraint(equalToConstant: 44),
            tambahPinButton.widthAnchor.constraint(equalToConstant: 90),

            tableView.topAnchor.constraint(equalTo: inputRow.bottomAnchor, constant: 14),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableView.bottomAnchor.constraint(equalTo: keluarButton.topAnchor, constant: -14),

            keluarButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            keluarButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            keluarButton.bottomAnchor.constraint(equalTo: footerLabel.topAnchor, constant: -10),
            keluarButton.heightAnchor.constraint(equalToConstant: 48),

            footerLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            footerLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            footerLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        ])
    }

    private func muatDaftarPin() {
        daftarPin = PrefsHelper.userPins()
        tableView.reloadData()
    }

    @objc private func tambahPinTapped() {
        let pin = (pinBaruField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard pin.count >= 4, pin.count <= 8, pin.allSatisfy({ $0.isNumber }) else {
            tampilkanAlert(pesan: "PIN harus 4\u{2013}8 digit angka.")
            return
        }
        if PrefsHelper.isAdminPin(pin) {
            tampilkanAlert(pesan: "PIN pengguna tidak boleh sama dengan PIN admin.")
            return
        }
        if !PrefsHelper.addUserPin(pin) {
            tampilkanAlert(pesan: "PIN tersebut sudah terdaftar.")
            return
        }

        pinBaruField.text = ""
        view.endEditing(true)
        muatDaftarPin()
    }

    private func tampilkanAlert(pesan: String) {
        let alert = UIAlertController(title: nil, message: pesan, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func bukaAplikasiTapped() {
        navigationController?.pushViewController(MainViewController(mode: .admin), animated: true)
    }

    @objc private func pengaturanGitHubTapped() {
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }

    @objc private func keluarTapped() {
        navigationController?.popToRootViewController(animated: true)
    }
}

extension AdminViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return daftarPin.isEmpty ? 1 : daftarPin.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "pinCell", for: indexPath)
        if daftarPin.isEmpty {
            cell.textLabel?.text = "Belum ada PIN pengguna. Tambahkan di atas."
            cell.textLabel?.textColor = .gray
            cell.selectionStyle = .none
        } else {
            cell.textLabel?.text = daftarPin[indexPath.row]
            cell.textLabel?.textColor = .label
            cell.selectionStyle = .default
            cell.accessoryType = .none
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !daftarPin.isEmpty else { return }

        let pin = daftarPin[indexPath.row]
        let alert = UIAlertController(
            title: "Hapus PIN?",
            message: "Pengguna dengan PIN \(pin) tidak akan bisa masuk lagi.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Batal", style: .cancel))
        alert.addAction(UIAlertAction(title: "Hapus", style: .destructive) { [weak self] _ in
            PrefsHelper.removeUserPin(pin)
            self?.muatDaftarPin()
        })
        present(alert, animated: true)
    }
}
