//
//  AddressPickerSheet.swift
//  FoodShare
//
//  Address picker modal with map view and reverse geocoding
//  Allows users to set their address via map pin or manual entry
//


#if !SKIP
#if !SKIP
import CoreLocation
#endif
#if !SKIP
import MapKit
#endif
import SwiftUI

// MARK: - Address Picker Sheet

struct AddressPickerSheet: View {
    @Environment(\.translationService) private var t
    @Environment(\.dismiss) private var dismiss

    @Binding var address: EditableAddress
    let onSave: () -> Void

    // Map state
    @State private var mapRegion: MKCoordinateRegion
    @State private var pinCoordinate: CLLocationCoordinate2D?
    @State private var isReverseGeocoding = false

    // UI state
    @State private var isManualEntryMode = false
    @State private var isRequestingLocation = false

    // Location manager for current location
    @State private var locationManager = CLLocationManager()

    init(address: Binding<EditableAddress>, onSave: @escaping () -> Void) {
        _address = address
        self.onSave = onSave

        // Initialize map region from existing address or default
        let initialCoordinate = address.wrappedValue.coordinate ?? CLLocationCoordinate2D(
            latitude: 38.5816,
            longitude: -121.4944
        )
        _mapRegion = State(initialValue: MKCoordinateRegion(
            center: initialCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
        _pinCoordinate = State(initialValue: address.wrappedValue.coordinate)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Map section
                        mapSection

                        // Action buttons
                        actionButtons

                        // Manual entry toggle
                        manualEntryToggle

                        // Manual entry form (if enabled)
                        if isManualEntryMode {
                            manualEntryForm
                        }

                        Spacer(minLength: Spacing.xxl)
                    }
                    .padding(Spacing.md)
                }
            }
            .navigationTitle(t.t("profile.edit.set_address"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t.t("common.cancel")) {
                        HapticManager.light()
                        dismiss()
                    }
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(t.t("common.save")) {
                        HapticManager.success()
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        address.hasContent
                            ? Color.DesignSystem.brandGreen
                            : Color.DesignSystem.textTertiary
                    )
                    .disabled(!address.hasContent)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Map Section

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(t.t("profile.edit.tap_map_hint"))
                .font(.DesignSystem.caption)
                .foregroundStyle(Color.DesignSystem.textSecondary)

            ZStack(alignment: .center) {
                Map(coordinateRegion: $mapRegion, interactionModes: [.pan, .zoom])
                    .frame(height: 250.0)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .onTapGesture { location in
                        // This doesn't work perfectly with Map, we'll use center pin instead
                    }

                // Center pin
                VStack(spacing: 0) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.DesignSystem.error)
                        .shadow(color: Color.black.opacity(0.3), radius: 4, y: 2)

                    // Pin shadow/stem
                    Ellipse()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 12.0, height: 4)
                        .offset(y: -2)
                }
                .offset(y: -18) // Offset so pin point is at center

                // Loading overlay during reverse geocoding
                if isReverseGeocoding {
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(Color.black.opacity(0.3))
                        .frame(height: 250.0)

                    ProgressView()
                        .tint(Color.white)
                }
            }

            // Use map center button
            Button {
                HapticManager.light()
                reverseGeocodeMapCenter()
            } label: {
                HStack(spacing: Spacing.sm) {
                    if isReverseGeocoding {
                        ProgressView()
                            .tint(Color.DesignSystem.brandBlue)
                    } else {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 16, weight: .medium))
                    }
                    Text("Use this location")
                        .font(.DesignSystem.bodyMedium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .stroke(Color.DesignSystem.brandBlue.opacity(0.3), lineWidth: 1)
                        )
                )
                .foregroundStyle(Color.DesignSystem.brandBlue)
            }
            .disabled(isReverseGeocoding)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        GlassForm {
            Button {
                HapticManager.light()
                requestCurrentLocation()
            } label: {
                HStack(spacing: Spacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .fill(Color.DesignSystem.brandGreen.opacity(0.15))
                            .frame(width: 36.0, height: 36)

                        if isRequestingLocation {
                            ProgressView()
                                .tint(Color.DesignSystem.brandGreen)
                        } else {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.DesignSystem.brandGreen)
                        }
                    }

                    Text(t.t("profile.edit.use_current"))
                        .font(.DesignSystem.bodyLarge)
                        .foregroundStyle(Color.DesignSystem.text)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.DesignSystem.textTertiary)
                }
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.98, haptic: .light))
            .disabled(isRequestingLocation)
        }
    }

    // MARK: - Manual Entry Toggle

    private var manualEntryToggle: some View {
        GlassForm {
            GlassToggleRow(
                isOn: $isManualEntryMode,
                title: t.t("profile.edit.manual_entry"),
                icon: "pencil.line",
                iconColor: .DesignSystem.brandOrange
            )
        }
    }

    // MARK: - Manual Entry Form

    private var manualEntryForm: some View {
        GlassForm(title: "Address Details") {
            VStack(spacing: Spacing.md) {
                GlassTextField(
                    t.t("profile.edit.address_line1"),
                    text: $address.addressLine1,
                    icon: "house.fill"
                )

                GlassTextField(
                    t.t("profile.edit.address_line2"),
                    text: $address.addressLine2,
                    icon: "building.2.fill"
                )

                GlassTextField(
                    t.t("profile.edit.city"),
                    text: $address.city,
                    icon: "building.columns.fill"
                )

                HStack(spacing: Spacing.sm) {
                    GlassTextField(
                        t.t("profile.edit.state"),
                        text: $address.stateProvince
                    )

                    GlassTextField(
                        t.t("profile.edit.postal_code"),
                        text: $address.postalCode,
                        keyboardType: .numbersAndPunctuation
                    )
                }

                GlassTextField(
                    t.t("profile.edit.country"),
                    text: $address.country,
                    icon: "globe"
                )
            }
        }
    }

    // MARK: - Location Methods

    private func requestCurrentLocation() {
        isRequestingLocation = true

        Task {
            // Check authorization
            let status = locationManager.authorizationStatus
            if status == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
                // Wait for authorization
                try? await Task.sleep(for: .seconds(1))
            }

            guard status == .authorizedWhenInUse || status == .authorizedAlways else {
                await MainActor.run {
                    isRequestingLocation = false
                }
                return
            }

            // Get current location
            if let location = locationManager.location {
                let coordinate = location.coordinate
                await MainActor.run {
                    mapRegion.center = coordinate
                }
                await reverseGeocode(coordinate)
            }

            await MainActor.run {
                isRequestingLocation = false
            }
        }
    }

    private func reverseGeocodeMapCenter() {
        let coordinate = mapRegion.center
        Task {
            await reverseGeocode(coordinate)
        }
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async {
        await MainActor.run {
            isReverseGeocoding = true
        }

        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)

            if let placemark = placemarks.first {
                await MainActor.run {
                    // Build street address
                    let streetNumber = placemark.subThoroughfare ?? ""
                    let street = placemark.thoroughfare ?? ""
                    address.addressLine1 = [streetNumber, street]
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")

                    address.city = placemark.locality ?? ""
                    address.stateProvince = placemark.administrativeArea ?? ""
                    address.postalCode = placemark.postalCode ?? ""
                    address.country = placemark.country ?? ""
                    address.latitude = coordinate.latitude
                    address.longitude = coordinate.longitude

                    pinCoordinate = coordinate
                    isReverseGeocoding = false

                    HapticManager.success()
                }
            }
        } catch {
            await MainActor.run {
                isReverseGeocoding = false
                HapticManager.error()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AddressPickerSheet(
        address: .constant(.empty),
        onSave: { print("Save tapped") }
    )
}

#endif
