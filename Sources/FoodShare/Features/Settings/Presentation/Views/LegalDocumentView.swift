//
//  LegalDocumentView.swift
//  Foodshare
//
//  Legal document viewer for Privacy Policy and Terms of Service
//

import FoodShareDesignSystem
import SafariServices
import SwiftUI

struct LegalDocumentView: View {
    @Environment(\.translationService) private var t
    let type: LegalDocumentType

    enum LegalDocumentType {
        case privacy
        case terms

        var titleKey: String {
            switch self {
            case .privacy:
                "settings.privacy_policy"
            case .terms:
                "settings.terms_of_service"
            }
        }

        // These are compile-time constant string literals — URL init will never fail
        // swiftlint:disable force_unwrapping
        var url: URL {
            switch self {
            case .privacy:
                URL(string: "https://foodshare.club/privacy")!
            case .terms:
                URL(string: "https://foodshare.club/terms")!
            }
        }
        // swiftlint:enable force_unwrapping

        var icon: String {
            switch self {
            case .privacy:
                "hand.raised.fill"
            case .terms:
                "doc.text.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            SafariWebView(url: type.url)
                .ignoresSafeArea()
                .navigationTitle(t.t(type.titleKey))
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Safari Web View

struct SafariWebView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true

        let safari = SFSafariViewController(url: url, configuration: config)
        safari.preferredControlTintColor = UIColor(Color.DesignSystem.primary)
        return safari
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview("Privacy") {
    LegalDocumentView(type: .privacy)
}

#Preview("Terms") {
    LegalDocumentView(type: .terms)
}
