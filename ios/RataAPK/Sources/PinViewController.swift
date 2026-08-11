import UIKit

class PinViewController: UIViewController {

    /// Nomor WhatsApp admin untuk tombol "Hubungi Admin" saat pengguna
    /// belum punya / lupa PIN. GANTI dengan nomor admin Anda sendiri,
    /// format internasional tanpa "+" dan tanpa spasi.
    private let nomorWaAdmin = "6285346527481"

    private let navyColor = UIColor(red: 6.0 / 255.0, green: 46.0 / 255.0, blue: 94.0 / 255.0, alpha: 1)
    private let bgColor = UIColor(red: 248.0 / 255.0, green: 250.0 / 255.0, blue: 252.0 / 255.0, alpha: 1)
    private let errorColor = UIColor(red: 211.0 / 255.0, green: 47.0 / 255.0, blue: 47.0 / 255.0, alpha: 1)

    private let logoImageView = UIImageView(image: UIImage(named: "brand_logo"))
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let pinField = UITextField()
    private let errorLabel = UILabel()
    private let masukButton = UIButton(type: .system)
    private let hubungiAdminButton = UIButton(type: .system)
    private let nomorAdminLabel = UILabel()
    private let footerLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = bgColor
        setupViews()

        let tap = UITapGestureRecognizer(target: self, action: #selector(tutupKeyboard))
        view.addGestureRecognizer(tap)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        pinField.text = ""
        errorLabel.isHidden = true
    }

    private func setupViews() {
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = "Masukkan PIN"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .darkText
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.text = "Masukkan PIN untuk membuka aplikasi"
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .darkGray
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        pinField.placeholder = "PIN"
        pinField.textAlignment = .center
        pinField.font = .systemFont(ofSize: 22)
        pinField.keyboardType = .numberPad
        pinField.isSecureTextEntry = true
        pinField.borderStyle = .roundedRect
        pinField.backgroundColor = .white
        pinField.delegate = self
        pinField.translatesAutoresizingMaskIntoConstraints = false

        errorLabel.text = "PIN salah. Coba lagi atau hubungi admin."
        errorLabel.font = .systemFont(ofSize: 13)
        errorLabel.textColor = errorColor
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false

        masukButton.setTitle("Masuk", for: .normal)
        masukButton.setTitleColor(.white, for: .normal)
        masukButton.backgroundColor = navyColor
        masukButton.layer.cornerRadius = 12
        masukButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        masukButton.addTarget(self, action: #selector(masukTapped), for: .touchUpInside)
        masukButton.translatesAutoresizingMaskIntoConstraints = false

        hubungiAdminButton.setTitle("Lupa / belum punya PIN? Hubungi Admin", for: .normal)
        hubungiAdminButton.setTitleColor(navyColor, for: .normal)
        hubungiAdminButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        hubungiAdminButton.titleLabel?.numberOfLines = 0
        hubungiAdminButton.titleLabel?.textAlignment = .center
        hubungiAdminButton.contentHorizontalAlignment = .center
        hubungiAdminButton.addTarget(self, action: #selector(hubungiAdminTapped), for: .touchUpInside)
        hubungiAdminButton.translatesAutoresizingMaskIntoConstraints = false

        nomorAdminLabel.text = "WhatsApp Admin: 0853-4652-7481"
        nomorAdminLabel.font = .systemFont(ofSize: 12)
        nomorAdminLabel.textColor = .gray
        nomorAdminLabel.textAlignment = .center
        nomorAdminLabel.translatesAutoresizingMaskIntoConstraints = false

        footerLabel.text = "@By Yusup -Putra Langit Technology 2026"
        footerLabel.font = .systemFont(ofSize: 10.5)
        footerLabel.textColor = .gray
        footerLabel.alpha = 0.7
        footerLabel.textAlignment = .center
        footerLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [
            logoImageView, titleLabel, subtitleLabel, pinField, errorLabel,
            masukButton, hubungiAdminButton, nomorAdminLabel
        ])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 14
        stack.setCustomSpacing(28, after: logoImageView)
        stack.setCustomSpacing(4, after: titleLabel)
        stack.setCustomSpacing(24, after: subtitleLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        view.addSubview(footerLabel)

        NSLayoutConstraint.activate([
            logoImageView.heightAnchor.constraint(equalToConstant: 90),
            pinField.heightAnchor.constraint(equalToConstant: 50),
            masukButton.heightAnchor.constraint(equalToConstant: 50),

            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -32),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),

            footerLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            footerLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            footerLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
    }

    @objc private func tutupKeyboard() {
        view.endEditing(true)
    }

    @objc private func masukTapped() {
        coba()
    }

    private func coba() {
        let pin = (pinField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if pin.isEmpty {
            tampilkanError()
            return
        }

        if PrefsHelper.isAdminPin(pin) {
            errorLabel.isHidden = true
            pinField.text = ""
            navigationController?.pushViewController(AdminViewController(), animated: true)
            return
        }

        if PrefsHelper.isValidUserPin(pin) {
            errorLabel.isHidden = true
            pinField.text = ""
            navigationController?.pushViewController(MainViewController(mode: .user), animated: true)
            return
        }

        tampilkanError()
    }

    private func tampilkanError() {
        errorLabel.isHidden = false
    }

    @objc private func hubungiAdminTapped() {
        let pesan = "Halo Admin, saya butuh PIN baru untuk masuk aplikasi RataAPK."
        let terenkode = pesan.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://wa.me/\(nomorWaAdmin)?text=\(terenkode)") else { return }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            let alert = UIAlertController(
                title: nil,
                message: "WhatsApp tidak ditemukan di perangkat ini.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}

extension PinViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        coba()
        return true
    }
}
