//
//  GlassDatePicker.swift
//  Foodshare
//
//  Liquid Glass v26 Date Picker with glass overlay presentation
//  Premium component for date/time selection with smooth animations
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Glass Date Picker

struct GlassDatePicker: View {
    @Binding var selection: Date
    let label: String
    let displayedComponents: DatePickerComponents
    let range: ClosedRange<Date>?

    @State private var isExpanded = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.translationService) private var t

    init(
        _ label: String,
        selection: Binding<Date>,
        displayedComponents: DatePickerComponents = [.date],
        in range: ClosedRange<Date>? = nil
    ) {
        self.label = label
        self._selection = selection
        self.displayedComponents = displayedComponents
        self.range = range
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        if displayedComponents.contains(.date) && displayedComponents.contains(.hourAndMinute) {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
        } else if displayedComponents.contains(.date) {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        } else {
            formatter.dateStyle = .none
            formatter.timeStyle = .short
        }
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Label
            if !label.isEmpty {
                Text(label)
                    .font(.DesignSystem.labelMedium)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            // Trigger Button
            Button {
                HapticFeedback.light()
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: displayedComponents.contains(.hourAndMinute) ? "clock.fill" : "calendar")
                        .font(.system(size: 18))
                        .foregroundColor(.DesignSystem.accentBlue)

                    Text(dateFormatter.string(from: selection))
                        .font(.DesignSystem.bodyMedium)
                        .foregroundColor(.DesignSystem.text)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.DesignSystem.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(.ultraThinMaterial)

                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(
                            isExpanded
                                ? Color.DesignSystem.accentBlue.opacity(0.5)
                                : Color.DesignSystem.glassBorder,
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: isExpanded ? Color.DesignSystem.accentBlue.opacity(0.2) : Color.black.opacity(0.05),
                    radius: isExpanded ? 8 : 4,
                    y: isExpanded ? 4 : 2
                )
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)

            // Expanded Picker
            if isExpanded {
                pickerContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
                    ))
            }
        }
        .opacity(isEnabled ? 1.0 : 0.6)
    }

    // MARK: - Picker Content

    @ViewBuilder
    private var pickerContent: some View {
        VStack(spacing: 0) {
            if let range {
                DatePicker(
                    "",
                    selection: $selection,
                    in: range,
                    displayedComponents: displayedComponents
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
            } else {
                DatePicker(
                    "",
                    selection: $selection,
                    displayedComponents: displayedComponents
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
            }

            // Done button
            Button {
                HapticFeedback.light()
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                    isExpanded = false
                }
            } label: {
                Text(t.t("common.done"))
                    .font(.DesignSystem.labelMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        LinearGradient(
                            colors: [Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.15), radius: 20, y: 10)
        .padding(.top, Spacing.xs)
    }
}

// MARK: - Compact Date Picker (Inline)

struct GlassDatePickerCompact: View {
    @Binding var selection: Date
    let displayedComponents: DatePickerComponents

    init(
        selection: Binding<Date>,
        displayedComponents: DatePickerComponents = [.date]
    ) {
        self._selection = selection
        self.displayedComponents = displayedComponents
    }

    var body: some View {
        DatePicker(
            "",
            selection: $selection,
            displayedComponents: displayedComponents
        )
        .datePickerStyle(.compact)
        .labelsHidden()
        .tint(Color.DesignSystem.accentBlue)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Time Picker Variant

struct GlassTimePicker: View {
    @Binding var selection: Date

    var body: some View {
        GlassDatePicker(
            "",
            selection: $selection,
            displayedComponents: .hourAndMinute
        )
    }
}

// MARK: - Previews

#Preview("Date Picker") {
    @Previewable @State var date = Date()

    VStack(spacing: Spacing.xl) {
        GlassDatePicker(
            "Expiration Date",
            selection: $date,
            displayedComponents: .date
        )

        GlassDatePicker(
            "Pickup Time",
            selection: $date,
            displayedComponents: [.date, .hourAndMinute]
        )
    }
    .padding()
    .background(
        LinearGradient(
            colors: [Color.DesignSystem.accentBlue.opacity(0.2), Color.DesignSystem.background],
            startPoint: .top,
            endPoint: .bottom
        )
    )
}

#Preview("Date Picker with Range") {
    @Previewable @State var date = Date()

    GlassDatePicker(
        "Select Date",
        selection: $date,
        displayedComponents: .date,
        in: Date()...Date().addingTimeInterval(60 * 60 * 24 * 30)
    )
    .padding()
    .background(Color.DesignSystem.background)
}

#Preview("Compact") {
    @Previewable @State var date = Date()

    HStack {
        Text("Expires:")
            .font(.DesignSystem.bodyMedium)

        Spacer()

        GlassDatePickerCompact(selection: $date)
    }
    .padding()
    .glassEffect()
    .padding()
    .background(Color.DesignSystem.background)
}
