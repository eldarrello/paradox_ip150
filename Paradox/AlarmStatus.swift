//
//  AlarmStatus.swift
//  Paradox
//
//  Created by Eldar Rello on 17.11.2025.
//


enum AlarmStatus: Int {
    case unset = 0
    case disarmed = 1
    case armed = 2
    case triggered = 3
    case armedSleep = 4
    case armedStay = 5
    case entryDelay = 6
    case exitDelay = 7
    case ready = 8
    case notReady = 9
    case instant = 10
    case unknown = -1
    
    var displayString: String {
        switch self {
        case .unset: return "Unset"
        case .disarmed: return "Disarmed"
        case .armed: return "Armed"
        case .triggered: return "Triggered!"
        case .armedSleep: return "Armed - Sleep"
        case .armedStay: return "Armed - Stay"
        case .entryDelay: return "Entry Delay"
        case .exitDelay: return "Exit Delay"
        case .ready: return "Ready to Arm"
        case .notReady: return "Not Ready"
        case .instant: return "Instant"
        case .unknown: return "Unknown"
        }
    }
    
    var canArm: Bool {
        return self == .ready || self == .disarmed
    }
    
    var canDisarm: Bool {
        return self == .armed || self == .armedSleep || self == .armedStay || self == .entryDelay || self == .exitDelay
    }
    
    var isAlarming: Bool {
        return self == .triggered
    }
}