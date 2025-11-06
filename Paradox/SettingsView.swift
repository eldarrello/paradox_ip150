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
                Section(header: Text("Connection Settings")) {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("IP Address", text: $ipAddress)
                        .textContentType(.URL)
                        .keyboardType(.numbersAndPunctuation)
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
                
                Section {
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
        
        paradoxService.connect(username: username, password: password, baseURL: "http://\(ipAddress)") { success in
            isTestingConnection = false
            testResult = success ? "Success: Connected to alarm system" : "Failed: Could not connect"
            
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
