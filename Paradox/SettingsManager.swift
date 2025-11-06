//
//  SettingsManager.swift
//  Paradox
//
//  Created by Eldar Rello on 17.11.2025.
//


import Foundation
import Combine

class SettingsManager: ObservableObject {
    @Published var username: String {
        didSet { UserDefaults.standard.set(username, forKey: "username") }
    }
    
    @Published var password: String {
        didSet { UserDefaults.standard.set(password, forKey: "password") }
    }
    
    @Published var ipAddress: String {
        didSet { UserDefaults.standard.set(ipAddress, forKey: "ipAddress") }
    }
    
    var baseURL: String {
        return "http://\(ipAddress)"
    }
    
    var hasValidSettings: Bool {
        return !username.isEmpty && !password.isEmpty && !ipAddress.isEmpty
    }
    
    init() {
        self.username = UserDefaults.standard.string(forKey: "username") ?? ""
        self.password = UserDefaults.standard.string(forKey: "password") ?? ""
        self.ipAddress = UserDefaults.standard.string(forKey: "ipAddress") ?? ""
    }
}
