import Foundation

/// Menjalankan alur "Build Otomatis" lewat GitHub REST API di iOS, mirror
/// dari GitHubBuildManager.java di versi Android:
///   1) unggah file project ke repo (Contents API)
///   2) picu workflow_dispatch
///   3) cari run yang baru saja terpicu, lalu pantau statusnya
///   4) kalau sukses, unduh artifact (.zip) hasil build
///
/// PENTING: semua method di sini BLOCKING (pakai semaphore untuk menunggu
/// URLSession selesai) supaya alurnya sinkron & mudah dibaca, sama seperti
/// versi Android yang pakai HttpURLConnection blocking. WAJIB dipanggil
/// dari background thread (bukan main thread) — dipakai oleh
/// BuildProgressViewController lewat DispatchQueue.global().
///
/// CATATAN: berbeda dari Android, iOS/Foundation TIDAK punya API unzip
/// bawaan. Jadi di sini kita cuma mengunduh artifact-nya dalam bentuk
/// .zip mentah (tidak diekstrak) — pengguna bisa membukanya lewat app
/// Files (yang punya dukungan ekstrak ZIP bawaan sejak iOS 13) atau
/// membagikannya ke perangkat lain. Lihat BuildProgressViewController.
struct GitHubBuildManager {

    struct BuildError: Error, LocalizedError {
        let pesan: String
        var errorDescription: String? { pesan }
    }

    struct HasilRun {
        let status: String
        let conclusion: String?
        let htmlUrl: String
    }

    let owner: String
    let repo: String
    let token: String
    let branch: String
    let workflowFile: String

    private var apiBase: String { "https://api.github.com/repos/\(owner)/\(repo)" }

    // ------------------------------------------------------------------
    // Utilitas jaringan sinkron (blocking) berbasis semaphore
    // ------------------------------------------------------------------
    private func requestSinkron(url: URL, method: String, body: Data? = nil,
                                 tambahAuth: Bool = true) throws -> (Int, Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        if tambahAuth {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        }
        if let body = body {
            request.httpBody = body
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }

        let semaphore = DispatchSemaphore(value: 0)
        var hasilData: Data = Data()
        var hasilResponse: HTTPURLResponse?
        var hasilError: Error?

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: config)

        let task = session.dataTask(with: request) { data, response, error in
            hasilData = data ?? Data()
            hasilResponse = response as? HTTPURLResponse
            hasilError = error
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()

        if let error = hasilError {
            throw BuildError(pesan: "Gagal menghubungi GitHub: \(error.localizedDescription)")
        }
        guard let response = hasilResponse else {
            throw BuildError(pesan: "Tidak ada respons dari GitHub.")
        }
        return (response.statusCode, hasilData, response)
    }

    private func pesanKesalahanHttp(_ code: Int, _ body: Data) -> String {
        let teks = String(data: body, encoding: .utf8) ?? ""
        let ringkas = teks.count > 300 ? String(teks.prefix(300)) + "..." : teks
        switch code {
        case 401:
            return "Token GitHub tidak valid atau sudah kedaluwarsa (HTTP 401). Perbarui token di Pengaturan."
        case 403:
            return "Token GitHub tidak punya izin yang cukup (HTTP 403). Pastikan token diberi izin \u{201c}Contents: Read & write\u{201d} dan \u{201c}Actions: Read & write\u{201d}. Detail: \(ringkas)"
        case 404:
            return "Repo/workflow tidak ditemukan (HTTP 404). Cek lagi nama owner/repo dan nama file workflow di Pengaturan."
        default:
            return "GitHub mengembalikan error (HTTP \(code)): \(ringkas)"
        }
    }

    // ------------------------------------------------------------------
    // 1) Unggah file project ke repo lewat Contents API
    // ------------------------------------------------------------------
    func unggahFile(fileURL: URL, pathTujuan: String, onProgress: @escaping (String) -> Void) throws {
        onProgress("Membaca file \u{201c}\(fileURL.lastPathComponent)\u{201d}...")
        let isi: Data
        do {
            isi = try Data(contentsOf: fileURL)
        } catch {
            throw BuildError(pesan: "Gagal membaca file: \(error.localizedDescription)")
        }
        if isi.count > 60 * 1024 * 1024 {
            throw BuildError(pesan: "File terlalu besar (maks sekitar 60MB lewat alur otomatis).")
        }
        let base64Isi = isi.base64EncodedString()

        onProgress("Mengunggah ke GitHub (\(pathTujuan))...")

        // Cek dulu apakah file itu sudah ada (butuh SHA lama untuk menimpanya)
        var shaLama: String? = nil
        guard let cekUrl = URL(string: apiBase + "/contents/" + pathTujuan + "?ref=" + branch) else {
            throw BuildError(pesan: "URL tidak valid.")
        }
        let (cekCode, cekData, _) = try requestSinkron(url: cekUrl, method: "GET")
        if cekCode == 200 {
            if let obj = try? JSONSerialization.jsonObject(with: cekData) as? [String: Any] {
                shaLama = obj["sha"] as? String
            }
        }

        var payload: [String: Any] = [
            "message": "RataAPK: unggah project dari aplikasi iOS (\(fileURL.lastPathComponent))",
            "content": base64Isi,
            "branch": branch
        ]
        if let shaLama = shaLama {
            payload["sha"] = shaLama
        }
        let bodyData = try JSONSerialization.data(withJSONObject: payload)

        guard let putUrl = URL(string: apiBase + "/contents/" + pathTujuan) else {
            throw BuildError(pesan: "URL tidak valid.")
        }
        let (code, data, _) = try requestSinkron(url: putUrl, method: "PUT", body: bodyData)
        if code != 200 && code != 201 {
            throw BuildError(pesan: pesanKesalahanHttp(code, data))
        }
    }

    // ------------------------------------------------------------------
    // 2) Picu workflow_dispatch
    // ------------------------------------------------------------------
    func picuWorkflow(appLabel: String, packageName: String, onProgress: @escaping (String) -> Void) throws -> Date {
        let waktuPicu = Date()
        onProgress("Menjalankan workflow GitHub Actions...")

        let payload: [String: Any] = [
            "ref": branch,
            "inputs": [
                "app_label": appLabel,
                "package_name": packageName,
                "build_android": "false",
                "build_ios": "true"
            ]
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: payload)

        guard let url = URL(string: apiBase + "/actions/workflows/" + workflowFile + "/dispatches") else {
            throw BuildError(pesan: "URL tidak valid.")
        }
        let (code, data, _) = try requestSinkron(url: url, method: "POST", body: bodyData)
        if code != 204 {
            throw BuildError(pesan: pesanKesalahanHttp(code, data))
        }
        return waktuPicu
    }

    // ------------------------------------------------------------------
    // 3) Cari run yang baru saja terpicu (dengan retry)
    // ------------------------------------------------------------------
    func cariRunTerbaru(waktuPicu: Date, onProgress: @escaping (String) -> Void) throws -> Int64 {
        onProgress("Mencari proses build yang baru dimulai...")
        let formatter = ISO8601DateFormatter()

        for _ in 0..<10 {
            guard let url = URL(string: apiBase + "/actions/workflows/" + workflowFile
                    + "/runs?event=workflow_dispatch&branch=" + branch + "&per_page=5") else {
                throw BuildError(pesan: "URL tidak valid.")
            }
            let (code, data, _) = try requestSinkron(url: url, method: "GET")
            if code == 200,
               let hasil = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let runs = hasil["workflow_runs"] as? [[String: Any]] {
                for run in runs {
                    guard let createdAtStr = run["created_at"] as? String,
                          let createdAt = formatter.date(from: createdAtStr) else { continue }
                    // toleransi 20 detik untuk perbedaan jam antara HP & server
                    if createdAt >= waktuPicu.addingTimeInterval(-20) {
                        if let idNum = run["id"] as? NSNumber {
                            return idNum.int64Value
                        }
                    }
                }
            }
            Thread.sleep(forTimeInterval: 3)
        }
        throw BuildError(pesan: "Proses build tidak ditemukan setelah menunggu. Cek langsung tab Actions di GitHub repo Anda.")
    }

    // ------------------------------------------------------------------
    // 4) Pantau status run sampai selesai
    // ------------------------------------------------------------------
    func pantauSampaiSelesai(runId: Int64, onProgress: @escaping (String) -> Void) throws -> HasilRun {
        var detikBerlalu = 0
        while true {
            guard let url = URL(string: apiBase + "/actions/runs/\(runId)") else {
                throw BuildError(pesan: "URL tidak valid.")
            }
            let (code, data, _) = try requestSinkron(url: url, method: "GET")
            if code != 200 {
                throw BuildError(pesan: pesanKesalahanHttp(code, data))
            }
            guard let run = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw BuildError(pesan: "Gagal membaca status build.")
            }
            let status = run["status"] as? String ?? "unknown"
            let conclusion = run["conclusion"] as? String
            let htmlUrl = run["html_url"] as? String ?? ""

            if status == "completed" {
                return HasilRun(status: status, conclusion: conclusion, htmlUrl: htmlUrl)
            }

            onProgress("Sedang build di GitHub Actions (\(status))... \(detikBerlalu)s")
            Thread.sleep(forTimeInterval: 6)
            detikBerlalu += 6

            if detikBerlalu > 20 * 60 {
                throw BuildError(pesan: "Build belum selesai setelah 20 menit. Cek langsung di: \(htmlUrl)")
            }
        }
    }

    // ------------------------------------------------------------------
    // 5) Unduh artifact (.zip mentah, tidak diekstrak - lihat catatan di atas)
    // ------------------------------------------------------------------
    func unduhArtifactZip(runId: Int64, folderTujuan: URL, onProgress: @escaping (String) -> Void) throws -> URL {
        onProgress("Mencari hasil build (artifact)...")
        guard let listUrl = URL(string: apiBase + "/actions/runs/\(runId)/artifacts") else {
            throw BuildError(pesan: "URL tidak valid.")
        }
        let (listCode, listData, _) = try requestSinkron(url: listUrl, method: "GET")
        if listCode != 200 {
            throw BuildError(pesan: pesanKesalahanHttp(listCode, listData))
        }
        guard let hasil = try? JSONSerialization.jsonObject(with: listData) as? [String: Any],
              let artifacts = hasil["artifacts"] as? [[String: Any]], !artifacts.isEmpty else {
            throw BuildError(pesan: "Build selesai tapi tidak ada artifact yang ditemukan.")
        }

        // Coba cari hasil .ipa bertanda tangan dulu, kalau tidak ada pakai build Simulator
        var artifactId: Int64? = nil
        var namaArtifact = ""
        for prioritas in ["ios-ipa-result", "ios-simulator-build"] {
            if let a = artifacts.first(where: { ($0["name"] as? String) == prioritas }),
               let idNum = a["id"] as? NSNumber {
                artifactId = idNum.int64Value
                namaArtifact = prioritas
                break
            }
        }
        guard let idArtifact = artifactId else {
            throw BuildError(pesan: "Artifact hasil build iOS tidak ditemukan.")
        }

        onProgress("Mengunduh \(namaArtifact)...")
        if !FileManager.default.fileExists(atPath: folderTujuan.path) {
            try FileManager.default.createDirectory(at: folderTujuan, withIntermediateDirectories: true)
        }
        let zipTujuan = folderTujuan.appendingPathComponent("\(namaArtifact).zip")
        try unduhKeFile(urlAwal: apiBase + "/actions/artifacts/\(idArtifact)/zip", tujuan: zipTujuan)
        return zipTujuan
    }

    /// Unduh URL (dengan otorisasi) ke file, mengikuti redirect manual.
    private func unduhKeFile(urlAwal: String, tujuan: URL) throws {
        var urlSaatIni = urlAwal
        var pakaiAuth = true

        for _ in 0..<5 {
            guard let url = URL(string: urlSaatIni) else {
                throw BuildError(pesan: "URL tidak valid saat mengunduh artifact.")
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            if pakaiAuth {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            }

            let semaphore = DispatchSemaphore(value: 0)
            var hasilData: Data?
            var hasilResponse: HTTPURLResponse?
            var hasilError: Error?

            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 60
            // Matikan redirect otomatis supaya kita bisa lepas header Authorization
            // saat pindah ke URL blob yang sudah bertanda tangan sendiri.
            let delegate = TanpaRedirectDelegate()
            let sessionManual = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

            let task = sessionManual.dataTask(with: request) { data, response, error in
                hasilData = data
                hasilResponse = response as? HTTPURLResponse
                hasilError = error
                semaphore.signal()
            }
            task.resume()
            semaphore.wait()
            sessionManual.finishTasksAndInvalidate()

            if let error = hasilError {
                throw BuildError(pesan: "Gagal mengunduh artifact: \(error.localizedDescription)")
            }
            guard let response = hasilResponse else {
                throw BuildError(pesan: "Tidak ada respons saat mengunduh artifact.")
            }

            if response.statusCode == 301 || response.statusCode == 302 || response.statusCode == 303 {
                guard let lokasi = response.value(forHTTPHeaderField: "Location") else {
                    throw BuildError(pesan: "Redirect tanpa alamat tujuan saat mengunduh artifact.")
                }
                urlSaatIni = lokasi
                pakaiAuth = false
                continue
            }

            if response.statusCode != 200 {
                throw BuildError(pesan: pesanKesalahanHttp(response.statusCode, hasilData ?? Data()))
            }

            guard let data = hasilData else {
                throw BuildError(pesan: "Data artifact kosong.")
            }
            try data.write(to: tujuan)
            return
        }
        throw BuildError(pesan: "Terlalu banyak redirect saat mengunduh artifact.")
    }
}

/// URLSessionTaskDelegate sederhana yang mematikan redirect otomatis,
/// supaya unduhKeFile() bisa menangani redirect secara manual (lepas
/// header Authorization saat pindah ke URL blob yang sudah bertanda
/// tangan sendiri di query string-nya).
private final class TanpaRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                     willPerformHTTPRedirection response: HTTPURLResponse,
                     newRequest request: URLRequest,
                     completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
