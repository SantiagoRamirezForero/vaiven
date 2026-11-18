import AppKit
import VaivenCore

/// Uso de la cuenta de Claude con la sesión de Claude Code de esta Mac.
///
/// «Agregar cuenta» lee la sesión que Claude Code guarda en el Llavero (con `/usr/bin/security`, como lo guarda
/// Claude Code) y pide el uso al endpoint que usa `/usage`. El token solo vive en memoria durante la petición y solo
/// va a api.anthropic.com: nunca se escribe ni se muestra. Lo único que se guarda es que la cuenta está agregada.
/// Con cuenta se lee al arrancar, cada 5 min, al despertar la Mac y con «Sincronizar».
@MainActor
final class ClaudeAccountController {
    static let connectedKey = "claudeConnected"
    private static let pollEvery: TimeInterval = 300
    private static let requestTimeout: TimeInterval = 20

    private(set) var connected: Bool
    private(set) var usage: ClaudeUsage?
    private(set) var syncing = false
    private(set) var lastError: ClaudeSyncError?
    var onChange: (() -> Void)?

    private var timer: DispatchSourceTimer?
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = requestTimeout
        return URLSession(configuration: config)
    }()

    init() { connected = UserDefaults.standard.bool(forKey: Self.connectedKey) }

    var presentation: ClaudePresentation {
        ClaudePresentation.make(connected: connected, usage: usage, syncing: syncing, error: lastError)
    }

    func start() {
        if connected { sync(); startTimer() }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // Al despertar la red tarda unos segundos.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                MainActor.assumeIsolated { if self?.connected == true { self?.sync() } }
            }
        }
    }

    /// El botón del panel: sin cuenta la agrega; con cuenta sincroniza.
    func press() { sync() }

    /// Quita la cuenta: deja de leer y olvida los números.
    func disconnect() {
        connected = false
        usage = nil
        lastError = nil
        UserDefaults.standard.set(false, forKey: Self.connectedKey)
        timer?.cancel()
        timer = nil
        onChange?()
    }

    /// Lee el uso ahora (si no se está leyendo ya). Sin cuenta, la agrega si encuentra la sesión de Claude Code.
    func sync() {
        guard !syncing else { return }
        syncing = true
        onChange?()
        DispatchQueue.global(qos: .utility).async { [session] in
            guard let credentials = Self.readCredentials() else {
                return DispatchQueue.main.async { MainActor.assumeIsolated { self.finish(found: false, .failure(.noLogin)) } }
            }
            if credentials.isExpired(now: Date()) {
                return DispatchQueue.main.async { MainActor.assumeIsolated { self.finish(found: true, .failure(.expired)) } }
            }
            Self.fetch(credentials, session: session) { result in
                DispatchQueue.main.async { MainActor.assumeIsolated { self.finish(found: true, result) } }
            }
        }
    }

    private func finish(found: Bool, _ result: Result<ClaudeUsage, ClaudeSyncError>) {
        syncing = false
        if found, !connected {
            connected = true
            UserDefaults.standard.set(true, forKey: Self.connectedKey)
            startTimer()
        }
        switch result {
        case .success(let next):
            usage = next
            lastError = nil
        case .failure(let error):
            lastError = error
        }
        onChange?()
    }

    private func startTimer() {
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + Self.pollEvery, repeating: Self.pollEvery, leeway: .seconds(10))
        timer.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.sync() } }
        timer.resume()
        self.timer = timer
    }

    // MARK: fuera del hilo principal

    /// La sesión de Claude Code en el Llavero, o nil si no hay (o la persona no dio acceso).
    nonisolated static func readCredentials() -> ClaudeCredentials? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", ClaudeCredentials.keychainService, "-w"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return ClaudeCredentials.parse(data)
    }

    nonisolated static func fetch(_ credentials: ClaudeCredentials, session: URLSession,
                                          completion: @escaping @Sendable (Result<ClaudeUsage, ClaudeSyncError>) -> Void) {
        var request = URLRequest(url: ClaudeUsageAPI.url)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(ClaudeUsageAPI.betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        session.dataTask(with: request) { data, response, error in
            if let error = error as? URLError {
                let offline: Set<URLError.Code> = [.notConnectedToInternet, .networkConnectionLost, .timedOut,
                                                   .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed]
                return completion(.failure(offline.contains(error.code) ? .offline : .other))
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 401 || status == 403 { return completion(.failure(.rejected)) }
            guard status == 200, let data, let usage = ClaudeUsageAPI.parse(data, fetchedAt: Date()) else {
                return completion(.failure(.other))
            }
            completion(.success(usage))
        }.resume()
    }
}

/// `Vaiven --check-claude`: prueba la cuenta sin abrir la isla (lo usan el instalador y quien instala).
/// Imprime una línea y sale con 0 si leyó el uso, 1 si no.
enum ClaudeCheck {
    private final class Box: @unchecked Sendable { var result: Result<ClaudeUsage, ClaudeSyncError> = .failure(.other) }

    static func run() -> Int32 {
        guard let credentials = ClaudeAccountController.readCredentials() else { return fail(.noLogin) }
        if credentials.isExpired(now: Date()) { return fail(.expired) }
        let box = Box()
        let done = DispatchSemaphore(value: 0)
        ClaudeAccountController.fetch(credentials, session: URLSession(configuration: .ephemeral)) { result in
            box.result = result
            done.signal()
        }
        done.wait()
        switch box.result {
        case .success(let usage):
            func pct(_ window: UsageWindow?) -> String { window.map { "\(Int($0.pct.rounded())) %" } ?? "–" }
            print("ok · sesión 5 h \(pct(usage.five)) · semana \(pct(usage.week))")
            return 0
        case .failure(let error):
            return fail(error)
        }
    }

    private static func fail(_ error: ClaudeSyncError) -> Int32 {
        print("error · \(error.text)")
        return 1
    }
}
