//
//  ContentView.swift
//  Paradox
//
//  Created by Eldar Rello on 17.11.2025.
//

import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var paradoxService = ParadoxService()
    @StateObject private var settingsManager = SettingsManager()
    @State private var showingSettings = false
    @State private var isAppActive = true
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Connection Status
                HStack {
                    Circle()
                        .fill(paradoxService.isConnected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(paradoxService.isConnected ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if paradoxService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.leading, 5)
                    }
                }
                
                // Status Display
                VStack(spacing: 10) {
                    Text("Alarm Status")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(paradoxService.currentStatus.displayString)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(statusColor)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .gray.opacity(0.2), radius: 5)
                
                // Control Button
                Button(action: handleControlAction) {
                    Text(controlButtonText)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(controlButtonColor)
                        .cornerRadius(12)
                }
                .disabled(!paradoxService.isConnected || !canPerformControlAction)
                .opacity((!paradoxService.isConnected || !canPerformControlAction) ? 0.6 : 1.0)
                
                // Manual Reconnect Button (visible when disconnected)
                if !paradoxService.isConnected && !paradoxService.isLoading {
                    Button(action: manualReconnect) {
                        Text("Reconnect")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Paradox Alarm")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(settingsManager)
                    .environmentObject(paradoxService)
            }
            .onAppear {
                // This only runs when the view first appears
                print("ContentView appeared - initial connection")
                reconnectIfNeeded()
                setupAppStateObservers()
            }
            .onDisappear {
                removeAppStateObservers()
            }
        }
    }
    
    private var statusColor: Color {
        switch paradoxService.currentStatus {
        case .triggered:
            return .red
        case .armed, .armedSleep, .armedStay:
            return .orange
        case .ready:
            return .green
        case .disarmed:
            return .blue
        default:
            return .primary
        }
    }
    
    private var controlButtonText: String {
        if paradoxService.currentStatus.canDisarm {
            return "Disarm"
        } else if paradoxService.currentStatus.canArm {
            return "Arm"
        } else {
            return "No Action Available"
        }
    }
    
    private var controlButtonColor: Color {
        if paradoxService.currentStatus.canDisarm {
            return .blue
        } else if paradoxService.currentStatus.canArm {
            return .orange
        } else {
            return .gray
        }
    }
    
    private var canPerformControlAction: Bool {
        return paradoxService.currentStatus.canArm || paradoxService.currentStatus.canDisarm
    }
    
    private func handleControlAction() {
        if paradoxService.currentStatus.canDisarm {
            paradoxService.disarm()
        } else if paradoxService.currentStatus.canArm {
            paradoxService.arm()
        }
    }
    
    private func manualReconnect() {
        reconnectIfNeeded()
    }
    
    private func reconnectIfNeeded() {
        guard settingsManager.hasValidSettings else { 
            print("Cannot reconnect - invalid settings")
            return 
        }
        
        if !paradoxService.isConnected && !paradoxService.isLoading {
            print("Attempting to reconnect...")
            paradoxService.connect(
                username: settingsManager.username,
                password: settingsManager.password,
                baseURL: settingsManager.baseURL
            ) { success in
                print("Reconnection \(success ? "successful" : "failed")")
            }
        } else {
            print("Already connected or connection in progress")
        }
    }
    
    // MARK: - App State Management
    
    private func setupAppStateObservers() {
        // Remove any existing observers first
        removeAppStateObservers()
        
        // Add observers for app state changes
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { _ in
                print("App will resign active - disconnecting")
                self.handleAppBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { _ in
                print("App did become active - reconnecting")
                self.handleAppForeground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { _ in
                print("App will terminate - disconnecting")
                self.paradoxService.disconnect()
            }
            .store(in: &cancellables)
    }
    
    private func removeAppStateObservers() {
        cancellables.removeAll()
    }
    
    private func handleAppBackground() {
        paradoxService.disconnect()
    }
    
    private func handleAppForeground() {
        // Small delay to ensure the app is fully active
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.reconnectIfNeeded()
        }
    }
}
