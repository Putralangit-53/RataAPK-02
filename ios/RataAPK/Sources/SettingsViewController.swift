import UIKit

/// Layar khusus admin untuk mengisi konfigurasi repo GitHub yang dipakai
/// alur "Build Otomatis": owner/repo, branch, nama file workflow,
/// Personal Access Token, serta nama aplikasi & package name default.
/// Mirror dari SettingsActivity.java di versi Android.
class SettingsViewController: UIViewController {

    private let bgColor = UIColor(red: 248.0/255.0, green: 250.0/255.0, blue: 252.0/255.0, alpha: 1)
    private let navyColor = UIColor(red: 6.0/255.0, green: 46.0/255.0, blue: 94.0/255.0, alpha: 1)
    private let errorColor = UIColor(red: 211.0/255.0, green: 47.0/255.0, blue: 47.0/255.0, alpha: 1)

    private let penjelasanLabel = UILabel()
    private var fieldOwner = UITextField()
    private var fieldRepo = UITextField()
    private var fieldToken = UITextField()
    private var fieldBranch = UITextField()
    private var fieldWorkflow = UITextField()
    private var fieldAppLabel = UITextField()
    private var fieldPackageName = UITextField()
    private let simpanButton = UIButton(type: .system)
    private let hapusTokenButton = UIButton(type: .system)
    private let footerLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Pengaturan GitHub"
        view.backgroundColor = bgColor
        setupViews()
        muatDariPenyimpanan()
    }

    private func buatLabel(_ teks: String) -> UILabel {
        let l = UILabel()
        l.text = teks
        l.font = .systemFont(ofSize: 12.5, weight: .semibold)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    private func buatField(placeholder: String, aman: Bool = false) -> UITextField {
        let f = UITextField()
        f.placeholder = placeholder
        f.borderStyle = .roundedRect
        f.backgroundColor = .white
        f.autocapitalizationType = .none
        f.autocorrectionType = .no
        f.isSecureTextEntry = aman
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }

    private func setupViews() {
        penjelasanLabel.text = "Isi data repo GitHub yang menyimpan workflow build-apps.yml. Token disimpan hanya di perangkat ini (tidak dikirim ke server RataAPK). Pakai Fine-grained Personal Access Token yang dibatasi ke satu repo ini saja, dengan izin \u{201c}Contents: Read & write\u{201d} dan \u{201c}Actions: Read & write\u{201d}."
        penjelasanLabel.font = .systemFont(ofSize: 12.5)
        penjelasanLabel.textColor = .darkGray
        penjelasanLabel.numberOfLines = 0
        penjelasanLabel.translatesAutoresizingMaskIntoConstraints = false

        fieldOwner = buatField(placeholder: "contoh: yusup-dev")
        fieldRepo = buatField(placeholder: "contoh: RataAPK-Android-Ios")
        fieldToken = buatField(placeholder: "github_pat_xxxxxxxxxxxx", aman: true)
        fieldBranch = buatField(placeholder: "main")
        fieldWorkflow = buatField(placeholder: "build-apps.yml")
        fieldAppLabel = buatField(placeholder: "RataAPK")
        fieldPackageName = buatField(placeholder: "id.rataapk.template")

        simpanButton.setTitle("Simpan Pengaturan", for: .normal)
        simpanButton.setTitleColor(.white, for: .normal)
        simpanButton.backgroundColor = navyColor
        simpanButton.layer.cornerRadius = 10
        simpanButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        simpanButton.addTarget(self, action: #selector(simpanTapped), for: .touchUpInside)
        simpanButton.translatesAutoresizingMaskIntoConstraints = false

        hapusTokenButton.setTitle("Hapus Token dari Perangkat Ini", for: .normal)
        hapusTokenButton.setTitleColor(.white, for: .normal)
        hapusTokenButton.backgroundColor = errorColor
        hapusTokenButton.layer.cornerRadius = 10
        hapusTokenButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        hapusTokenButton.addTarget(self, action: #selector(hapusTokenTapped), for: .touchUpInside)
        hapusTokenButton.translatesAutoresizingMaskIntoConstraints = false

        footerLabel.text = "@By Yusup -Putra Langit Technology 2026"
        footerLabel.font = .systemFont(ofSize: 10.5)
        footerLabel.textColor = .gray
        footerLabel.alpha = 0.7
        footerLabel.textAlignment = .center
        footerLabel.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let stack = UIStackView(arrangedSubviews: [
            penjelasanLabel,
            buatLabel("Pemilik repo (username/organisasi)"), fieldOwner,
            buatLabel("Nama repo"), fieldRepo,
            buatLabel("Personal Access Token"), fieldToken,
            buatLabel("Branch"), fieldBranch,
            buatLabel("Nama file workflow"), fieldWorkflow,
            buatLabel("Nama aplikasi default"), fieldAppLabel,
            buatLabel("Package name default"), fieldPackageName,
            simpanButton, hapusTokenButton
        ])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(20, after: penjelasanLabel)
        stack.setCustomSpacing(16, after: fieldOwner)
        stack.setCustomSpacing(16, after: fieldRepo)
        stack.setCustomSpacing(16, after: fieldToken)
        stack.setCustomSpacing(16, after: fieldBranch)
        stack.setCustomSpacing(16, after: fieldWorkflow)
        stack.setCustomSpacing(16, after: fieldAppLabel)
        stack.setCustomSpacing(24, after: fieldPackageName)
        stack.setCustomSpacing(10, after: simpanButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        scrollView.addSubview(footerLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),

            simpanButton.heightAnchor.constraint(equalToConstant: 48),
            hapusTokenButton.heightAnchor.constraint(equalToConstant: 44),

            footerLabel.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 20),
            footerLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            footerLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            footerLabel.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20)
        ])

        let semuaField = [fieldOwner, fieldRepo, fieldToken, fieldBranch, fieldWorkflow, fieldAppLabel, fieldPackageName]
        NSLayoutConstraint.activate(semuaField.map { $0.heightAnchor.constraint(equalToConstant: 44) })
    }

    private func muatDariPenyimpanan() {
        fieldOwner.text = GitHubSettings.owner
        fieldRepo.text = GitHubSettings.repo
        fieldToken.text = GitHubSettings.token
        fieldBranch.text = GitHubSettings.branch
        fieldWorkflow.text = GitHubSettings.workflowFile
        fieldAppLabel.text = GitHubSettings.appLabel
        fieldPackageName.text = GitHubSettings.packageName
    }

    @objc private func simpanTapped() {
        let owner = fieldOwner.text ?? ""
        let repo = fieldRepo.text ?? ""
        let token = fieldToken.text ?? ""

        guard !owner.trimmingCharacters(in: .whitespaces).isEmpty,
              !repo.trimmingCharacters(in: .whitespaces).isEmpty,
              !token.trimmingCharacters(in: .whitespaces).isEmpty else {
            tampilkanAlert(pesan: "Pemilik repo, nama repo, dan token wajib diisi")
            return
        }

        GitHubSettings.simpan(
            owner: owner,
            repo: repo,
            token: token,
            branch: fieldBranch.text ?? "",
            workflowFile: fieldWorkflow.text ?? "",
            appLabel: fieldAppLabel.text ?? "",
            packageName: fieldPackageName.text ?? ""
        )
        tampilkanAlert(pesan: "Pengaturan tersimpan") { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }

    @objc private func hapusTokenTapped() {
        GitHubSettings.hapusToken()
        fieldToken.text = ""
        tampilkanAlert(pesan: "Token dihapus dari perangkat ini")
    }

    private func tampilkanAlert(pesan: String, selesai: (() -> Void)? = nil) {
        let alert = UIAlertController(title: nil, message: pesan, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in selesai?() })
        present(alert, animated: true)
    }
}
