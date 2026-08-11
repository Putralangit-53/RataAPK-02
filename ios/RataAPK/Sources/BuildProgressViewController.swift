import UIKit

/// Menjalankan alur "Build Otomatis" (unggah -> picu workflow -> pantau ->
/// unduh artifact) di background thread, sambil menampilkan log berjalan.
/// Mirror dari BuildProgressActivity.java di versi Android, dengan satu
/// perbedaan penting: iOS/Foundation tidak punya API unzip bawaan, jadi di
/// sini hasil akhirnya adalah file .zip mentah yang ditawarkan lewat Share
/// Sheet (AirDrop/Simpan ke Files/dst) — bukan tombol "pasang" langsung
/// seperti di Android, karena iOS memang tidak mengizinkan instalasi app
/// pihak ketiga tanpa proses signing & distribusi resmi Apple.
class BuildProgressViewController: UIViewController {

    private let fileURL: URL
    private let labelJenis: String

    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let logTextView = UITextView()
    private let aksiButton = UIButton(type: .system)

    private var hasilZip: URL?
    private var sedangBerjalan = true

    private let jamFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    init(fileURL: URL, labelJenis: String) {
        self.fileURL = fileURL
        self.labelJenis = labelJenis
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) tidak digunakan")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Build Otomatis"
        view.backgroundColor = UIColor(red: 248.0/255.0, green: 250.0/255.0, blue: 252.0/255.0, alpha: 1)
        navigationItem.hidesBackButton = true
        setupViews()
        jalankanBuild()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            sedangBerjalan = false
        }
    }

    private func setupViews() {
        statusLabel.text = "Memulai\u{2026}"
        statusLabel.font = .systemFont(ofSize: 16, weight: .bold)
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        activityIndicator.startAnimating()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        logTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        logTextView.backgroundColor = UIColor(red: 15.0/255.0, green: 23.0/255.0, blue: 42.0/255.0, alpha: 1)
        logTextView.textColor = UIColor(red: 143.0/255.0, green: 247.0/255.0, blue: 176.0/255.0, alpha: 1)
        logTextView.isEditable = false
        logTextView.layer.cornerRadius = 10
        logTextView.translatesAutoresizingMaskIntoConstraints = false

        aksiButton.setTitle("Tutup", for: .normal)
        aksiButton.setTitleColor(.white, for: .normal)
        aksiButton.backgroundColor = UIColor(red: 6.0/255.0, green: 46.0/255.0, blue: 94.0/255.0, alpha: 1)
        aksiButton.layer.cornerRadius = 10
        aksiButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        aksiButton.isHidden = true
        aksiButton.addTarget(self, action: #selector(aksiTapped), for: .touchUpInside)
        aksiButton.translatesAutoresizingMaskIntoConstraints = false

        [statusLabel, activityIndicator, logTextView, aksiButton].forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: activityIndicator.leadingAnchor, constant: -12),

            activityIndicator.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            activityIndicator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            logTextView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            logTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            logTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            logTextView.bottomAnchor.constraint(equalTo: aksiButton.topAnchor, constant: -16),

            aksiButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            aksiButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            aksiButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            aksiButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    private func tulisLog(_ pesan: String) {
        let waktu = jamFormatter.string(from: Date())
        logTextView.text += "[\(waktu)] \(pesan)\n"
        let panjang = (logTextView.text as NSString).length
        let bawah = NSRange(location: max(0, panjang - 1), length: panjang > 0 ? 1 : 0)
        logTextView.scrollRangeToVisible(bawah)
    }

    private func jalankanBuild() {
        let owner = GitHubSettings.owner
        let repo = GitHubSettings.repo
        let token = GitHubSettings.token
        let branch = GitHubSettings.branch
        let workflowFile = GitHubSettings.workflowFile
        let appLabel = GitHubSettings.appLabel
        let packageName = GitHubSettings.packageName
        let namaFile = fileURL.lastPathComponent
        let jenis = labelJenis

        let manager = GitHubBuildManager(owner: owner, repo: repo, token: token,
                                          branch: branch, workflowFile: workflowFile)

        let onProgress: (String) -> Void = { [weak self] pesan in
            DispatchQueue.main.async {
                self?.tulisLog(pesan)
                self?.statusLabel.text = pesan
            }
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let pathTujuan = namaFile.lowercased().hasSuffix(".zip")
                    ? "incoming/website.zip"
                    : "incoming/\(namaFile)"

                try manager.unggahFile(fileURL: self.fileURL, pathTujuan: pathTujuan, onProgress: onProgress)
                guard self.sedangBerjalan else { return }

                let waktuPicu = try manager.picuWorkflow(appLabel: appLabel, packageName: packageName, onProgress: onProgress)
                guard self.sedangBerjalan else { return }

                let runId = try manager.cariRunTerbaru(waktuPicu: waktuPicu, onProgress: onProgress)
                guard self.sedangBerjalan else { return }

                let hasil = try manager.pantauSampaiSelesai(runId: runId, onProgress: onProgress)
                guard self.sedangBerjalan else { return }

                guard hasil.conclusion == "success" else {
                    let pesanGagal = "Build selesai tapi gagal (\(hasil.conclusion ?? "unknown")). Cek log lengkapnya di: \(hasil.htmlUrl)"
                    DispatchQueue.main.async { self.gagalkan(pesanGagal) }
                    return
                }

                let folderTujuan = FileManager.default.temporaryDirectory.appendingPathComponent("rataapk_build_\(jenis.hashValue)")
                let zip = try manager.unduhArtifactZip(runId: runId, folderTujuan: folderTujuan, onProgress: onProgress)
                guard self.sedangBerjalan else { return }

                self.hasilZip = zip
                DispatchQueue.main.async { self.selesaiDenganSukses(zip) }

            } catch let error as GitHubBuildManager.BuildError {
                DispatchQueue.main.async { self.gagalkan(error.pesan) }
            } catch {
                DispatchQueue.main.async { self.gagalkan("Terjadi kesalahan tak terduga: \(error.localizedDescription)") }
            }
        }
    }

    private func selesaiDenganSukses(_ zip: URL) {
        activityIndicator.stopAnimating()
        statusLabel.text = "Build berhasil \u{2014} siap dibagikan"

        var ukuranKB = 0
        if let atribut = try? FileManager.default.attributesOfItem(atPath: zip.path),
           let ukuranByte = atribut[.size] as? Int {
            ukuranKB = ukuranByte / 1024
        }
        tulisLog("Build berhasil! Artifact: \(zip.lastPathComponent) (\(ukuranKB) KB)")
        tulisLog("Catatan: hasilnya berupa .zip dari GitHub. Buka lewat app Files (ketuk untuk ekstrak otomatis) untuk mengambil isinya.")
        aksiButton.setTitle("Bagikan Hasil Build", for: .normal)
        aksiButton.isHidden = false
    }

    private func gagalkan(_ pesanError: String) {
        activityIndicator.stopAnimating()
        statusLabel.text = "Build gagal"
        tulisLog("GAGAL: \(pesanError)")
        aksiButton.setTitle("Tutup", for: .normal)
        aksiButton.isHidden = false
    }

    @objc private func aksiTapped() {
        guard let zip = hasilZip else {
            navigationController?.popViewController(animated: true)
            return
        }
        let pesan = "Hasil build otomatis RataAPK (\(labelJenis)): \(zip.lastPathComponent). Buka lewat app Files untuk mengekstrak isinya."
        let activity = UIActivityViewController(activityItems: [pesan, zip], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        present(activity, animated: true)
    }
}
