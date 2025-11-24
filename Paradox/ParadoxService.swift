//
//  ParadoxService.swift
//  Paradox
//
//  Created by Eldar Rello on 17.11.2025.
//


import Foundation
import CryptoKit
import Combine

class ParadoxService: ObservableObject {
    private var session: URLSession?
    private var baseURL: String = ""
    private var currentSessionID: String = ""
    
    @Published var isConnected: Bool = false
    @Published var currentStatus: AlarmStatus = .unknown
    @Published var isLoading: Bool = false
    @Published var lastError: String? = nil
    
    private var pollingTimer: Timer?
    private var connectionAttempts: Int = 0
    private let maxConnectionAttempts = 3
    
    // MARK: - Initialization
    
    init() {
        self.session = URLSession(configuration: .default)
    }
    
    // MARK: - Crypto Functions
    
    private func keepLowByte(_ sValue: String) -> String {
        var result = ""
        for char in sValue {
            let shortVal = Int(char.unicodeScalars.first!.value) % 256
            if let scalar = UnicodeScalar(shortVal) {
                result.append(Character(scalar))
            }
        }
        return result
    }
    
    private func hexMD5(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02hhX", $0) }.joined()
    }
    
    private func decimalToHex(_ decimal: Int) -> String {
        let hex = String(format: "%02X", decimal & 0xFF)
        return hex.count == 1 ? "0" + hex : hex
    }
    
    private func rc4Encrypt(key: String, text: String) -> String {
        var s = Array(0...255)
        var j = 0
        let keyLength = key.count
        
        // Key-scheduling algorithm (matches JavaScript version)
        var x = keyLength
        while x > 0 {
            x -= 1
            let keyIndex = key.index(key.startIndex, offsetBy: x)
            let keyChar = key[keyIndex]
            j = (j + Int(keyChar.asciiValue!) + s[x]) % 256
            s.swapAt(x, j)
        }
        
        // Pseudo-random generation algorithm (matches JavaScript version)
        var i = 0
        j = 0
        var result = ""
        
        for char in text {
            j = (j + s[i]) % 256
            s.swapAt(i, j)
            let k = s[(s[i] + s[j]) % 256]
            let temp = Int(char.asciiValue!) ^ k
            result += decimalToHex(temp)
            i = (i + 1) % 256
        }
        
        return result
    }
    
    private func loginEncrypt(username: String, password: String, sessionID: String) -> (String, String) {
        let lowBytePassword = keepLowByte(password)
        let tempHash = hexMD5(lowBytePassword)
        let combined = tempHash + sessionID
        let pValue = hexMD5(combined)
        let uValue = rc4Encrypt(key: combined, text: username)
        
        return (uValue, pValue)
    }
    
    // MARK: - Session Management
    
    private func constructURL(path: String, baseURL: String) -> URL? {
        // If baseURL already has http://, use it as is, otherwise prepend http://
        let fullBaseURL: String
        if baseURL.lowercased().hasPrefix("http://") || baseURL.lowercased().hasPrefix("https://") {
            fullBaseURL = baseURL
        } else {
            fullBaseURL = "http://\(baseURL)"
        }
        
        // Ensure there's exactly one slash between baseURL and path
        let separator = fullBaseURL.hasSuffix("/") ? "" : "/"
        let fullURLString = "\(fullBaseURL)\(separator)\(path)"
        
        return URL(string: fullURLString)
    }
    
    // MARK: - Session Management
    
    func getSessionID(baseURL: String, completion: @escaping (String?) -> Void) {
        guard let url = constructURL(path: "login_page.html", baseURL: baseURL) else {
            completion(nil)
            return
        }
        
        print("Fetching session ID from: \(url.absoluteString)")
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error getting session ID: \(error)")
                DispatchQueue.main.async {
                    self.lastError = "Network error: \(error.localizedDescription)"
                }
                completion(nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self.lastError = "Invalid response from server"
                }
                completion(nil)
                return
            }
            
            print("Session ID response status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200, let data = data, let htmlString = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    self.lastError = "Server returned status code: \(httpResponse.statusCode)"
                }
                completion(nil)
                return
            }
            
            // Parse session ID using regex
            let pattern = #"loginaff\s*\(\s*"([^"]+)"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString)),
               let range = Range(match.range(at: 1), in: htmlString) {
                
                let sessionID = String(htmlString[range])
                DispatchQueue.main.async {
                    self.lastError = nil
                    completion(sessionID)
                }
            } else {
                DispatchQueue.main.async {
                    self.lastError = "Could not find session ID in response"
                }
                completion(nil)
            }
        }
        task.resume()
    }
    
    func connect(username: String, password: String, baseURL: String, completion: @escaping (Bool) -> Void) {
        guard !isLoading else {
            completion(false)
            return
        }
        
        isLoading = true
        connectionAttempts += 1
        
        getSessionID(baseURL: baseURL) { [weak self] sessionID in
            guard let self = self else {
                completion(false)
                return
            }
            
            guard let sessionID = sessionID else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    completion(false)
                }
                return
            }
            
            self.currentSessionID = sessionID
            self.baseURL = baseURL
            
            let (uValue, pValue) = self.loginEncrypt(username: username, password: password, sessionID: sessionID)
            
            // Construct the authentication URL
            let authPath = "default.html?u=\(uValue)&p=\(pValue)"
            guard let authURL = self.constructURL(path: authPath, baseURL: baseURL) else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    completion(false)
                }
                return
            }
            
            print("Authenticating with URL: \(authURL.absoluteString)")
            
            let task = URLSession.shared.dataTask(with: authURL) { data, response, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        print("Authentication error: \(error)")
                        self.lastError = "Authentication failed: \(error.localizedDescription)"
                        completion(false)
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        self.lastError = "Invalid response from server"
                        completion(false)
                        return
                    }
                    
                    print("Authentication response status: \(httpResponse.statusCode)")
                    
                    guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                        self.lastError = "No response data received"
                        completion(false)
                        return
                    }
                    
                    // Check if authentication was successful
                    let isAuthenticated = !responseString.contains("href='login_page.html")
                    self.isConnected = isAuthenticated
                    
                    if isAuthenticated {
                        self.lastError = nil
                        self.connectionAttempts = 0 // Reset attempts on success
                        self.startPolling()
                        print("Successfully connected to Paradox system")
                    } else {
                        self.lastError = "Authentication failed - invalid credentials or connection"
                        print("Authentication failed - still on login page")
                    }
                    
                    completion(isAuthenticated)
                }
            }
            task.resume()
        }
    }
    
    func disconnect() {
        print("Disconnecting from Paradox system")
        pollingTimer?.invalidate()
        pollingTimer = nil
        
        guard !baseURL.isEmpty else { 
            self.isConnected = false
            return 
        }
        
        guard let url = constructURL(path: "logout.html", baseURL: baseURL) else {
            self.isConnected = false
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] _, _, _ in
            DispatchQueue.main.async {
                self?.isConnected = false
                self?.currentStatus = .unknown
                print("Disconnected from Paradox system")
            }
        }
        task.resume()
    }
    
    // MARK: - Status Management
    
    private func startPolling() {
        pollingTimer?.invalidate()
        // Start polling immediately, then every second
        getStatus()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.getStatus()
        }
    }
    
    func getStatus(area: String = "", value: String = "") {
        guard isConnected else { return }
        
        var statusPath = "statuslive.html"
        if !area.isEmpty {
            statusPath += "?area=\(area)&value=\(value)"
        }
        
        guard let url = constructURL(path: statusPath, baseURL: baseURL) else { return }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Status polling error: \(error)")
                // If we get a network error, we might be disconnected
                DispatchQueue.main.async {
                    self.isConnected = false
                }
                return
            }
            
            guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                return
            }
            
            // Check if we got logged out
            if responseString.contains("href='login_page.html") {
                DispatchQueue.main.async {
                    self.isConnected = false
                    print("Got logged out during status polling")
                }
                return
            }
            
            if responseString.contains("tbl_useraccess = new Array(") {
                let components = responseString.components(separatedBy: "tbl_useraccess = new Array(")
                if components.count >= 2 {
                    let statusPart = components[1]
                    if let statusChar = statusPart.first, let statusInt = Int(String(statusChar)) {
                        DispatchQueue.main.async {
                            self.currentStatus = AlarmStatus(rawValue: statusInt) ?? .unknown
                        }
                    }
                }
            }
        }
        task.resume()
    }

    func arm() {
        getStatus(area: "00", value: "r")
    }
    
    func disarm() {
        getStatus(area: "00", value: "d")
    }
    
    deinit {
        pollingTimer?.invalidate()
        disconnect()
    }
}
