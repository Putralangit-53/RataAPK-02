import Foundation

/// Menyimpan konfigurasi GitHub yang dipakai alur "Build Otomatis" di iOS:
/// repo tujuan, branch, nama file workflow, dan Personal Access Token (PAT).
/// Mirror dari GitHubSettings.java di versi Android — perilaku dan nama
/// method disamakan supaya mudah dirawat berdampingan.
///
/// CATATAN KEAMANAN: sama seperti versi Android, token disimpan di
/// UserDefaults biasa (bukan Keychain, bukan terenkripsi). Aman dari
/// aplikasi lain di sandbox iOS normal, tapi tetap disarankan pakai
/// Fine-grained PAT yang dibatasi ke satu repo saja, dengan izin minimal
/// dan masa berlaku (expiration) yang jelas.
enum GitHubSettings {

    private static let kOwner = "rataapk_gh_owner"
    private static let kRepo = "rataapk_gh_repo"
    private static let kToken = "rataapk_gh_token"
    private static let kBranch = "rataapk_gh_branch"
    private static let kWorkflowFile = "rataapk_gh_workflow_file"
    private static let kAppLabel = "rataapk_gh_app_label"
    private static let kPackageName = "rataapk_gh_package_name"

    static var owner: String {
        get { UserDefaults.standard.string(forKey: kOwner) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: kOwner) }
    }

    static var repo: String {
        get { UserDefaults.standard.string(forKey: kRepo) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: kRepo) }
    }

    static var token: String {
        get { UserDefaults.standard.string(forKey: kToken) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: kToken) }
    }

    static var branch: String {
        get {
            let b = UserDefaults.standard.string(forKey: kBranch) ?? ""
            return b.isEmpty ? "main" : b
        }
        set { UserDefaults.standard.set(newValue, forKey: kBranch) }
    }

    static var workflowFile: String {
        get {
            let w = UserDefaults.standard.string(forKey: kWorkflowFile) ?? ""
            return w.isEmpty ? "build-apps.yml" : w
        }
        set { UserDefaults.standard.set(newValue, forKey: kWorkflowFile) }
    }

    static var appLabel: String {
        get {
            let a = UserDefaults.standard.string(forKey: kAppLabel) ?? ""
            return a.isEmpty ? "RataAPK" : a
        }
        set { UserDefaults.standard.set(newValue, forKey: kAppLabel) }
    }

    static var packageName: String {
        get {
            let p = UserDefaults.standard.string(forKey: kPackageName) ?? ""
            return p.isEmpty ? "id.rataapk.template" : p
        }
        set { UserDefaults.standard.set(newValue, forKey: kPackageName) }
    }

    /// true kalau owner, repo, dan token sudah diisi (syarat minimum build otomatis).
    static func sudahDikonfigurasi() -> Bool {
        return !owner.isEmpty && !repo.isEmpty && !token.isEmpty
    }

    static func simpan(owner: String, repo: String, token: String, branch: String,
                        workflowFile: String, appLabel: String, packageName: String) {
        self.owner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        self.repo = repo.trimmingCharacters(in: .whitespacesAndNewlines)
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        self.branch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        self.workflowFile = workflowFile.trimmingCharacters(in: .whitespacesAndNewlines)
        self.appLabel = appLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.packageName = packageName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func hapusToken() {
        UserDefaults.standard.removeObject(forKey: kToken)
    }
}
