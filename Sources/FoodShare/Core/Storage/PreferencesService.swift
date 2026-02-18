//
//  PreferencesService.swift
//  Foodshare
//
//  User preferences storage service using AppStorage
//



#if !SKIP
import Foundation
import SwiftUI

/// Service for managing user preferences with persistent storage
@MainActor
final class PreferencesService {
    // MARK: - Properties
    
    /// Search radius in kilometers (localized to miles if needed)
    @AppStorage("searchRadius") var searchRadius: Double = 5.0
    
    /// Whether push notifications are enabled
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = true
    
    /// Whether location services are enabled
    @AppStorage("locationEnabled") var locationEnabled: Bool = true
    
    /// Whether message alerts are enabled
    @AppStorage("messageAlertsEnabled") var messageAlertsEnabled: Bool = true
    
    /// Whether like notifications are enabled
    @AppStorage("likeNotificationsEnabled") var likeNotificationsEnabled: Bool = true
    
    // MARK: - Singleton
    
    static let shared = PreferencesService()
    
    private init() {}
    
    // MARK: - Methods
    
    /// Reset all preferences to defaults
    func resetToDefaults() {
        searchRadius = 5.0
        notificationsEnabled = true
        locationEnabled = true
        messageAlertsEnabled = true
        likeNotificationsEnabled = true
    }
    
    /// Validate and clamp search radius to acceptable range
    func validateSearchRadius() {
        let min = DistanceUnit.localizedMinSlider
        let max = DistanceUnit.localizedMaxSlider
        
        if searchRadius < min {
            searchRadius = min
        } else if searchRadius > max {
            searchRadius = max
        }
    }
}


#endif
