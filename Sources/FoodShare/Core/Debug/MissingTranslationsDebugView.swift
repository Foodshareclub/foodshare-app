//
//  MissingTranslationsDebugView.swift
//  Foodshare
//
//  Debug view to display missing translation keys
//

import SwiftUI
import FoodShareDesignSystem

#if DEBUG
    struct MissingTranslationsDebugView: View {
        @Environment(\.translationService) private var t
        @State private var missingKeys: [String] = []
        @State private var searchText = ""

        var filteredKeys: [String] {
            if searchText.isEmpty {
                return missingKeys.sorted()
            }
            return missingKeys.filter { $0.localizedCaseInsensitiveContains(searchText) }.sorted()
        }

        var body: some View {
            NavigationStack {
                VStack(spacing: 0) {
                    // Stats header
                    statsHeader

                    // Search bar
                    searchBar

                    // Missing keys list
                    if filteredKeys.isEmpty {
                        emptyState
                    } else {
                        keysList
                    }
                }
                .navigationTitle("Missing Translations")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            copyAllKeys()
                        } label: {
                            Label("Copy All", systemImage: "doc.on.doc")
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            exportToJSON()
                        } label: {
                            Label("Export JSON", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                .onAppear {
                    refreshKeys()
                }
            }
        }

        private var statsHeader: some View {
            VStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.xl) {
                    StatBox(
                        title: "Missing Keys",
                        value: "\(missingKeys.count)",
                        color: .red,
                    )

                    StatBox(
                        title: "Total Keys",
                        value: "\(t.translationCount)",
                        color: .green,
                    )

                    StatBox(
                        title: "Coverage",
                        value: String(format: "%.1f%%", coverage),
                        color: coverage > 95 ? .green : .orange,
                    )
                }
                .padding(.horizontal)
                .padding(.top)

                if !missingKeys.isEmpty {
                    Text("These keys are being used in the app but don't have translations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, Spacing.sm)
                }
            }
            .background(Color(.systemGroupedBackground))
        }

        private var searchBar: some View {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search keys...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(Spacing.sm)
            .background(Color(.systemBackground))
            .cornerRadius(CornerRadius.medium)
            .padding(.horizontal)
            .padding(.vertical, Spacing.sm)
        }

        private var keysList: some View {
            List {
                ForEach(filteredKeys, id: \.self) { key in
                    KeyRow(key: key)
                }
            }
            .listStyle(.plain)
        }

        private var emptyState: some View {
            VStack(spacing: Spacing.md) {
                Image(systemName: searchText.isEmpty ? "checkmark.circle.fill" : "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(searchText.isEmpty ? .green : .secondary)

                Text(searchText.isEmpty ? "All translations found!" : "No matching keys")
                    .font(.headline)

                if searchText.isEmpty {
                    Text("Every translation key used in the app has a corresponding translation")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        private var coverage: Double {
            let total = Double(t.translationCount + missingKeys.count)
            guard total > 0 else { return 100 }
            return (Double(t.translationCount) / total) * 100
        }

        private func refreshKeys() {
            missingKeys = Array(t.missingTranslationKeys)
        }

        private func copyAllKeys() {
            let text = filteredKeys.joined(separator: "\n")
            UIPasteboard.general.string = text
        }

        private func exportToJSON() {
            var json: [String: String] = [:]
            for key in filteredKeys {
                // Create nested structure from dot notation
                json[key] = key.split(separator: ".").last.map(String.init) ?? key
            }

            if let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let jsonString = String(data: data, encoding: .utf8)
            {
                UIPasteboard.general.string = jsonString
            }
        }
    }

    struct KeyRow: View {
        let key: String
        @State private var copied = false

        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(key)
                        .font(.system(.body, design: .monospaced))

                    if let suggestion = suggestedValue {
                        Text("Suggested: \"\(suggestion)\"")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button {
                    UIPasteboard.general.string = key
                    copied = true

                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(2))
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .foregroundColor(copied ? .green : .blue)
                }
            }
            .padding(.vertical, 4)
        }

        private var suggestedValue: String? {
            // Try to generate a human-readable suggestion from the key
            let parts = key.split(separator: ".")
            guard let last = parts.last else { return nil }

            // Convert snake_case or camelCase to Title Case
            let words = String(last)
                .replacingOccurrences(of: "_", with: " ")
                .split(whereSeparator: { $0.isUppercase || $0 == " " })
                .map(\.capitalized)

            return words.joined(separator: " ")
        }
    }

    struct StatBox: View {
        let title: String
        let value: String
        let color: Color

        var body: some View {
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(Color(.systemBackground))
            .cornerRadius(CornerRadius.medium)
        }
    }

    #Preview {
        MissingTranslationsDebugView()
    }
#endif
