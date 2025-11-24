//
//  SettingsView.swift
//  Paradox
//
//  Created by Eldar Rello on 17.11.2025.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var paradoxService: ParadoxService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var ipAddress: String = ""
    @State private var isTestingConnection = false
    @State private var testResult: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Connection Settings"), footer: Text("Examples: 192.168.1.100, or http://mydomain.com:8080")) {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("IP Address or Domain", text: $ipAddress)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section {
                    Button(action: testConnection) {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                            if isTestingConnection {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isTestingConnection || !hasValidInput)
                    
                    if let result = testResult {
                        Text(result)
                            .foregroundColor(result.contains("Success") ? .green : .red)
                    }
                }
                
                Section(footer: Text("App will automatically connect using these settings when opened.")) {
                    Button("Save Settings") {
                        saveSettings()
                    }
                    .disabled(!hasValidInput)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                username = settingsManager.username
                password = settingsManager.password
                ipAddress = settingsManager.ipAddress
            }
        }
    }
    
    private var hasValidInput: Bool {
        return !username.isEmpty && !password.isEmpty && !ipAddress.isEmpty
    }
    
    private func testConnection() {
        isTestingConnection = true
        testResult = nil
        
        // Construct base URL for testing
        let testBaseURL: String
        if ipAddress.lowercased().hasPrefix("http://") || ipAddress.lowercased().hasPrefix("https://") {
            testBaseURL = ipAddress
        } else {
            testBaseURL = "http://\(ipAddress)"
        }
        
        paradoxService.connect(username: username, password: password, baseURL: testBaseURL) { success in
            isTestingConnection = false
            testResult = success ? "Success: Connected to alarm system" : "Failed: Could not connect to \(testBaseURL)"
            
            // Disconnect after test
            if success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    paradoxService.disconnect()
                }
            }
        }
    }
    
    private func saveSettings() {
        settingsManager.username = username
        settingsManager.password = password
        settingsManager.ipAddress = ipAddress
        presentationMode.wrappedValue.dismiss()
    }
}
