import UIKit
import WebKit
import UniformTypeIdentifiers

/// WebView utama, dibuka setelah PIN benar (admin ataupun pengguna).
/// Memuat dashboard yang sama persis dengan versi Android
/// (RataAPK/www/index.html) dari dalam bundle aplikasi.
///
/// Juga menyediakan jembatan JS <-> native lewat WKScriptMessageHandler
/// bernama "rataapk", supaya kartu "Konversi" di dashboard benar-benar
/// bisa memilih & membagikan file (mirror dari WebAppInterface di versi
/// Android), bukan cuma dekorasi.
class MainViewController: UIViewController {

    enum Mode {
        case admin
        case user
    }

    private let mode: Mode
    private var webView: WKWebView!

    /// Nomor WhatsApp admin, dipakai di pesan share. Samakan dengan
    /// PinViewController.nomorWaAdmin.
    private let nomorWaAdmin = "6285346527481"

    init(mode: Mode) {
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) tidak digunakan")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(false, animated: false)

        let namaApp = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "RataAPK"
        title = mode == .admin ? "\(namaApp) \u{2022} Mode Admin" : namaApp

        view.backgroundColor = .white
        setupWebView()
        setupNavigationItems()
        muatDashboard()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        // Pakai wrapper weak-reference supaya tidak retain-cycle: WKUserContentController
        // menyimpan message handler secara strong, dan config disimpan oleh webView yang
        // adalah properti "self" — tanpa wrapper ini, self tidak akan pernah di-dealloc.
        config.userContentController.add(WeakScriptMessageHandler(target: self), name: "rataapk")

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupNavigationItems() {
        var items: [UIBarButtonItem] = []
        if mode == .admin {
            items.append(UIBarButtonItem(
                title: "Kelola PIN",
                style: .plain,
                target: self,
                action: #selector(kelolaPinTapped)
            ))
        }
        items.append(UIBarButtonItem(
            title: "Keluar",
            style: .plain,
            target: self,
            action: #selector(keluarTapped)
        ))
        navigationItem.rightBarButtonItems = items
    }

    private func muatDashboard() {
        guard let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "www") else {
            tampilkanKontenKosong()
            return
        }
        let readAccessURL = url.deletingLastPathComponent()
        webView.loadFileURL(url, allowingReadAccessTo: readAccessURL)
    }

    private func tampilkanKontenKosong() {
        let html = """
        <html><body style="font-family:-apple-system;display:flex;
        align-items:center;justify-content:center;height:100vh;margin:0;
        text-align:center;padding:24px;color:#062E5E;">
        <div><h2>RataAPK</h2>
        <p>Website belum diupload. Upload website Anda lewat workflow build
        untuk mengganti halaman ini.</p></div></body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    @objc private func kelolaPinTapped() {
        navigationController?.pushViewController(AdminViewController(), animated: true)
    }

    @objc private func keluarTapped() {
        navigationController?.popToRootViewController(animated: true)
    }

    // MARK: - Alur "Konversi": pilih file lalu bagikan

    /// Menyimpan label jenis konversi ("HTML Upload", dst) yang lagi
    /// diproses, dipakai lagi setelah delegate document picker dipanggil.
    /// (Tidak pakai `picker.title` karena UIDocumentPickerViewController
    /// adalah UI sistem yang mengelola judulnya sendiri — tidak bisa
    /// diandalkan untuk menitipkan data.)
    private var labelJenisAktif = "Project"

    /// true = hasil pilih file akan diproses lewat alur "Build Otomatis"
    /// (GitHub API), false = dibagikan manual lewat Share Sheet biasa.
    private var modeBuildOtomatisAktif = false

    private func mulaiPilihFile(labelJenis: String) {
        labelJenisAktif = labelJenis
        modeBuildOtomatisAktif = GitHubSettings.sudahDikonfigurasi()
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    private func bagikanFile(url: URL, labelJenis: String) {
        let pesan = """
        Project "\(labelJenis)" dari RataAPK: \(url.lastPathComponent)

        Langkah selanjutnya: unggah file ini sebagai incoming/website.zip di \
        repo GitHub Anda, lalu jalankan workflow "Build RataAPK (Android & iOS)" \
        untuk menghasilkan APK/IPA. Atau kirim file ini ke Admin lewat WhatsApp \
        0853-4652-7481 kalau ingin dibantu build-kan.
        """

        let activity = UIActivityViewController(activityItems: [pesan, url], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        present(activity, animated: true)
    }

    private func salinTeks(_ teks: String) {
        UIPasteboard.general.string = teks
        let alert = UIAlertController(
            title: nil,
            message: "URL disalin ke clipboard. Kirim ke Admin lewat WhatsApp, atau tempelkan saat mengisi workflow di GitHub Actions.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension MainViewController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        // Tetap di dalam WebView untuk semua navigasi, tidak lempar ke
        // browser luar (mirror WebViewClient bawaan di versi Android).
        decisionHandler(.allow)
    }
}

extension MainViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "rataapk",
              let body = message.body as? [String: Any],
              let aksi = body["aksi"] as? String else { return }

        switch aksi {
        case "pilihFile":
            let label = (body["label"] as? String) ?? "Project"
            mulaiPilihFile(labelJenis: label)
        case "salinTeks":
            let teks = (body["teks"] as? String) ?? ""
            salinTeks(teks)
        default:
            break
        }
    }
}

extension MainViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        if modeBuildOtomatisAktif {
            let progress = BuildProgressViewController(fileURL: url, labelJenis: labelJenisAktif)
            navigationController?.pushViewController(progress, animated: true)
        } else {
            bagikanFile(url: url, labelJenis: labelJenisAktif)
        }
    }
}

/// Wrapper weak-reference untuk WKScriptMessageHandler supaya tidak
/// terjadi retain cycle antara WKUserContentController dan view controller.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?

    init(target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
