//
//  FAQ.swift
//  Foodshare
//
//  Domain model for Help Center FAQs
//


#if !SKIP
import Foundation

/// Represents a FAQ item
struct FAQ: Identifiable, Sendable {
    let id = UUID()
    let question: String
    let answer: String
}

/// Represents a FAQ section/category
struct FAQSection: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let icon: String
    let faqs: [FAQ]

    static let allSections: [FAQSection] = [
        FAQSection(
            title: "Getting Started",
            icon: "play.circle.fill",
            faqs: [
                FAQ(
                    question: "How do I create an account?",
                    answer: "Tap the \"Sign Up\" button and register with your email or Apple ID. Complete your profile to start sharing food with your community.",
                ),
                FAQ(
                    question: "How do I share food?",
                    answer: "Tap the \"+\" button to create a new listing. Add photos, description, pickup location, and availability. Your listing will appear on the map for nearby users.",
                ),
                FAQ(
                    question: "How do I find food near me?",
                    answer: "Use the interactive map to browse available food in your area. You can filter by food type, distance, and availability. Tap on a listing to see details and contact the sharer.",
                )
            ],
        ),
        FAQSection(
            title: "Food Safety",
            icon: "checkmark.shield.fill",
            faqs: [
                FAQ(
                    question: "What food can I share?",
                    answer: "Share surplus food that is still safe to eat - unopened packaged goods, fresh produce, home-cooked meals, and baked goods. Always be honest about ingredients and preparation date.",
                ),
                FAQ(
                    question: "What are the food safety tips?",
                    answer: "Check expiration dates before sharing. Store food at proper temperatures. List all allergens and ingredients. Use clean containers for transport. When in doubt, don't share it.",
                )
            ],
        ),
        FAQSection(
            title: "Using the App",
            icon: "iphone",
            faqs: [
                FAQ(
                    question: "How do I message someone?",
                    answer: "Open a listing and tap \"Message\" to start a chat with the sharer. Use chat to coordinate pickup time and location.",
                ),
                FAQ(
                    question: "How do I edit or delete my listing?",
                    answer: "Go to your profile and find the listing under \"My Listings\". Tap the menu icon to edit details or mark as collected/delete.",
                ),
                FAQ(
                    question: "What are community fridges?",
                    answer: "Community fridges are public refrigerators where anyone can leave or take food. They appear on the map with a special icon. Check their hours and guidelines before visiting.",
                )
            ],
        ),
        FAQSection(
            title: "Account & Privacy",
            icon: "lock.shield.fill",
            faqs: [
                FAQ(
                    question: "How do I change my settings?",
                    answer: "Go to Settings from your profile menu. You can update your email, password, notification preferences, and privacy settings.",
                ),
                FAQ(
                    question: "Is my location shared?",
                    answer: "Your exact location is never shared. Listings show an approximate area. You control what location details to share when coordinating pickup.",
                ),
                FAQ(
                    question: "How do I delete my account?",
                    answer: "Go to Settings > Account > Delete Account. This will permanently remove your profile, listings, and messages.",
                ),
                FAQ(
                    question: "Is Foodshare free?",
                    answer: "Yes, Foodshare is completely free to use. We believe in building community through sharing.",
                )
            ],
        )
    ]
}

#endif
