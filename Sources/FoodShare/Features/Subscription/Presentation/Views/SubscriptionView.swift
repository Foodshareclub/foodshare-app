//
//  SubscriptionView.swift
//  Foodshare
//
//  Premium subscription paywall with EULA and Privacy Policy links
//  Required for App Store Guideline 3.1.2 compliance
//


#if !SKIP
import OSLog
#if !SKIP
import StoreKit
#endif
import SwiftUI

struct SubscriptionView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.translationService) private var t
    @Environment(AppState.self) private var appState

    // MARK: - State

    @State private var storeService: StoreKitService = StoreKitService.shared
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var animateHeader = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated gradient background
                backgroundGradient

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Hero Header with premium effects
                        heroHeaderSection

                        // Benefits with glass cards
                        benefitsSection

                        // Products with premium styling
                        if !storeService.products.isEmpty {
                            productsSection
                        } else if storeService.error != nil {
                            emptyProductsView
                        } else if storeService.isLoading {
                            loadingView
                        } else {
                            loadingView
                        }

                        // Premium CTA button
                        purchaseButton

                        // Legal section
                        legalSection
                    }
                    .padding(Spacing.lg)
                    .padding(.top, Spacing.xl)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                            #if !SKIP
                            .symbolRenderingMode(.hierarchical)
                            #endif
                    }
                }
            }
            .alert(t.t("common.error.title"), isPresented: $showError) {
                Button(t.t("common.ok"), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .task {
                if storeService.products.isEmpty {
                    await storeService.loadProducts()
                }
                if selectedProduct == nil {
                    selectedProduct = storeService.yearlyProduct ?? storeService.monthlyProduct
                }

                // Animate header entrance
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                    animateHeader = true
                }
            }
            .onChange(of: storeService.products) { oldValue, newValue in
                if selectedProduct == nil, !newValue.isEmpty {
                    selectedProduct = storeService.yearlyProduct ?? storeService.monthlyProduct
                }
            }
        }
    }

    // MARK: - Background Gradient

    private var backgroundGradient: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color.DesignSystem.brandPink.opacity(0.15),
                    Color.DesignSystem.brandPurple.opacity(0.15),
                    Color.DesignSystem.accentCyan.opacity(0.1),
                    Color.DesignSystem.background,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
            .ignoresSafeArea()

            // Animated aurora overlay
            #if !SKIP
            TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                RadialGradient(
                    colors: [
                        Color.DesignSystem.brandGreen.opacity(0.08 + sin(time * 0.3) * 0.03),
                        Color.clear,
                    ],
                    center: UnitPoint(
                        x: 0.5 + cos(time * 0.2) * 0.3,
                        y: 0.3 + sin(time * 0.15) * 0.2,
                    ),
                    startRadius: 0,
                    endRadius: 400,
                )
            }
            .ignoresSafeArea()
            #else
            RadialGradient(
                colors: [
                    Color.DesignSystem.brandGreen.opacity(0.08),
                    Color.clear,
                ],
                center: UnitPoint(x: 0.5, y: 0.3),
                startRadius: 0,
                endRadius: 400,
            )
            .ignoresSafeArea()
            #endif
        }
    }

    // MARK: - Hero Header

    private var heroHeaderSection: some View {
        VStack(spacing: Spacing.lg) {
            // Premium icon with holographic effect
            ZStack {
                // Glow rings
                ForEach(0 ..< 3) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.brandPink.opacity(0.3),
                                    Color.DesignSystem.accentCyan.opacity(0.2),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                            lineWidth: 2,
                        )
                        .frame(width: 120.0 + CGFloat(index * 30), height: 120 + CGFloat(index * 30))
                        .opacity(animateHeader ? 0.3 : 0)
                        .scaleEffect(animateHeader ? 1.2 : 0.8)
                        .animation(
                            .easeOut(duration: 1.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: animateHeader,
                        )
                }

                // Main icon
                Image(systemName: "crown.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.brandPink,
                                Color.DesignSystem.brandPurple,
                                Color.DesignSystem.accentCyan,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .shadow(color: Color.DesignSystem.brandPink.opacity(0.5), radius: 20)
                    .scaleEffect(animateHeader ? 1.0 : 0.5)
                    .rotationEffect(.degrees(animateHeader ? 0 : -180))
                    .animation(.spring(response: 0.8, dampingFraction: 0.6), value: animateHeader)
            }
            .frame(height: 180.0)

            VStack(spacing: Spacing.sm) {
                Text(t.t("subscription.foodshare_premium"))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.brandPink,
                                Color.DesignSystem.brandPurple,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing,
                        ),
                    )
                    .opacity(animateHeader ? 1 : 0)
                    .offset(y: animateHeader ? 0 : 20)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3), value: animateHeader)

                Text(t.t("subscription.support_mission"))
                    .font(.DesignSystem.bodyLarge)
                    .foregroundColor(Color.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(animateHeader ? 1 : 0)
                    .offset(y: animateHeader ? 0 : 20)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.4), value: animateHeader)
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Benefits Section

    private var benefitsSection: some View {
        VStack(spacing: Spacing.md) {
            ForEach(Array(benefits.enumerated()), id: \.offset) { index, benefit in
                benefitCard(
                    icon: benefit.icon,
                    title: benefit.title,
                    description: benefit.description,
                    gradient: benefit.gradient,
                )
                .opacity(animateHeader ? 1 : 0)
                .offset(x: animateHeader ? 0 : -30)
                .animation(
                    .spring(response: 0.7, dampingFraction: 0.7)
                        .delay(0.5 + Double(index) * 0.1),
                    value: animateHeader,
                )
            }
        }
    }

    private var benefits: [(icon: String, title: String, description: String, gradient: [Color])] {
        [
            (
                icon: "heart.fill",
                title: t.t("subscription.benefit.support_title"),
                description: t.t("subscription.benefit.support_desc"),
                gradient: [Color.DesignSystem.brandPink, Color.red.opacity(0.8)],
            ),
            (
                icon: "sparkles",
                title: t.t("subscription.benefit.badge_title"),
                description: t.t("subscription.benefit.badge_desc"),
                gradient: [Color.DesignSystem.accentCyan, Color.DesignSystem.brandTeal],
            ),
            (
                icon: "bolt.fill",
                title: t.t("subscription.benefit.priority_title"),
                description: t.t("subscription.benefit.priority_desc"),
                gradient: [Color.DesignSystem.brandPurple, Color.DesignSystem.accentPurple],
            ),
            (
                icon: "leaf.fill",
                title: t.t("subscription.benefit.eco_title"),
                description: t.t("subscription.benefit.eco_desc"),
                gradient: [Color.DesignSystem.brandGreen, Color.DesignSystem.brandTeal],
            ),
        ]
    }

    private func benefitCard(icon: String, title: String, description: String, gradient: [Color]) -> some View {
        HStack(spacing: Spacing.md) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .frame(width: 56.0, height: 56)
                    .shadow(color: gradient[0].opacity(0.4), radius: 8, y: 4)

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.DesignSystem.textPrimary)

                Text(description)
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(Color.DesignSystem.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        #if !SKIP
        .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
        #else
        .background(Color.DesignSystem.glassSurface.opacity(0.15))
        #endif
        .cornerRadius(CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                    lineWidth: 1,
                ),
        )
        .shadow(color: Color.black.opacity(0.1), radius: 12, y: 6)
    }

    // MARK: - Products Section

    private var productsSection: some View {
        VStack(spacing: Spacing.md) {
            ForEach(storeService.products, id: \.id) { product in
                productCard(product)
                    .opacity(animateHeader ? 1 : 0)
                    .offset(y: animateHeader ? 0 : 30)
                    .animation(
                        .spring(response: 0.7, dampingFraction: 0.7)
                            .delay(0.9),
                        value: animateHeader,
                    )
            }
        }
    }

    private func productCard(_ product: Product) -> some View {
        let isSelected = selectedProduct?.id == product.id
        let isYearly = product.id.contains("year") || product.id.contains("annual")
        let pricingInfo = calculatePricingInfo(for: product, isYearly: isYearly)

        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                selectedProduct = product
            }
            HapticManager.medium()
        } label: {
            VStack(spacing: 0) {
                // Best Value Badge
                if isYearly, pricingInfo.hasSavings {
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text(t.t("subscription.best_value"))
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.DesignSystem.brandPink,
                                            Color.DesignSystem.brandPurple,
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing,
                                    ),
                                )
                                .shadow(color: Color.DesignSystem.brandPink.opacity(0.5), radius: 8, y: 2),
                        )
                        Spacer()
                    }
                    .offset(y: -12)
                    .zIndex(1)
                }

                HStack(alignment: .center, spacing: Spacing.md) {
                    // Left side - Plan info
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: isYearly ? "star.fill" : "star")
                                .font(.system(size: 20))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: isSelected
                                            ? [
                                                Color.DesignSystem.brandPink,
                                                Color.DesignSystem.brandPurple,
                                            ]
                                            : [
                                                Color.DesignSystem.textSecondary,
                                                Color.DesignSystem.textSecondary,
                                            ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing,
                                    ),
                                )

                            Text(isYearly ? t.t("subscription.yearly") : t.t("subscription.monthly"))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color.DesignSystem.textPrimary)
                        }

                        Text(subscriptionPeriod(for: product))
                            .font(.DesignSystem.bodySmall)
                            .foregroundColor(Color.DesignSystem.textSecondary)

                        // Show effective monthly price for yearly
                        if isYearly, pricingInfo.hasSavings {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pricingInfo.effectiveMonthlyText)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.DesignSystem.success)

                                Text(pricingInfo.annualCostComparison)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color.DesignSystem.textTertiary)
                            }
                        }
                    }

                    Spacer()

                    // Right side - Pricing
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(product.displayPrice)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: isSelected
                                        ? [
                                            Color.DesignSystem.brandPink,
                                            Color.DesignSystem.brandPurple,
                                        ]
                                        : [
                                            Color.DesignSystem.textPrimary,
                                            Color.DesignSystem.textPrimary,
                                        ],
                                    startPoint: .leading,
                                    endPoint: .trailing,
                                ),
                            )

                        if pricingInfo.hasSavings {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 12))
                                Text("Save \(pricingInfo.savingsPercent)%")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(Color.DesignSystem.success)
                        }
                    }
                }
                .padding(Spacing.lg)
                .padding(.top, isYearly && pricingInfo.hasSavings ? Spacing.sm : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }
            .background(
                ZStack {
                    if isSelected {
                        // Selected state with holographic effect
                        RoundedRectangle(cornerRadius: CornerRadius.xl)
                            #if !SKIP
                            .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                            #else
                            .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                            #endif

                        RoundedRectangle(cornerRadius: CornerRadius.xl)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.DesignSystem.brandPink,
                                        Color.DesignSystem.brandPurple,
                                        Color.DesignSystem.accentCyan,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                                lineWidth: 2.5,
                            )
                            .shadow(color: Color.DesignSystem.brandPink.opacity(0.5), radius: 16, y: 4)

                        // Inner glow
                        RoundedRectangle(cornerRadius: CornerRadius.xl)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.DesignSystem.brandPink.opacity(0.1),
                                        Color.clear,
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom,
                                ),
                            )
                    } else {
                        // Unselected state
                        RoundedRectangle(cornerRadius: CornerRadius.xl)
                            #if !SKIP
                            .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                            #else
                            .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                            #endif

                        RoundedRectangle(cornerRadius: CornerRadius.xl)
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                    }
                },
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .shadow(
                color: isSelected ? Color.DesignSystem.brandPink.opacity(0.3) : Color.black.opacity(0.1),
                radius: isSelected ? 20 : 8,
                y: isSelected ? 8 : 4,
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        #if !SKIP
        .accessibilityElement(children: .combine)
        #endif
        .accessibilityLabel(accessibilityLabel(for: product, isYearly: isYearly, pricing: pricingInfo))
        .accessibilityHint(isSelected ? "Selected" : "Double tap to select")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Generates comprehensive accessibility label for screen readers
    private func accessibilityLabel(for product: Product, isYearly: Bool, pricing: PricingInfo) -> String {
        let period = subscriptionPeriod(for: product)
        var label = isYearly ? "Yearly subscription" : "Monthly subscription"
        label += ", \(product.displayPrice)"

        if !period.isEmpty {
            label += " per \(period)"
        }

        if isYearly, pricing.hasSavings {
            label += ", \(pricing.effectiveMonthlyText)"
            label += ", Save \(pricing.savingsPercent) percent"
            label += ", Best value"
        }

        return label
    }

    // MARK: - Pricing Calculation

    /// Comprehensive pricing information for a subscription product
    private struct PricingInfo {
        let hasSavings: Bool
        let savingsPercent: Int
        let savingsAmount: Decimal
        let effectiveMonthlyPrice: Decimal
        let effectiveMonthlyText: String
        let annualCostComparison: String

        static let zero = PricingInfo(
            hasSavings: false,
            savingsPercent: 0,
            savingsAmount: 0,
            effectiveMonthlyPrice: 0,
            effectiveMonthlyText: "",
            annualCostComparison: "",
        )
    }

    /// Calculates comprehensive pricing information with proper currency formatting
    /// - Parameters:
    ///   - product: The subscription product to analyze
    ///   - isYearly: Whether this is a yearly subscription
    /// - Returns: Complete pricing breakdown including savings and comparisons
    private func calculatePricingInfo(for product: Product, isYearly: Bool) -> PricingInfo {
        guard isYearly, let monthly = storeService.monthlyProduct else {
            return .zero
        }

        // Calculate costs
        let effectiveMonthly = product.price / 12
        let monthlyAnnualCost = monthly.price * 12
        let yearlyAnnualCost = product.price

        // Validate pricing makes sense (yearly should be cheaper)
        guard monthlyAnnualCost > yearlyAnnualCost else {
            return .zero
        }

        // Calculate savings
        let savingsAmount = monthlyAnnualCost - yearlyAnnualCost
        let savingsPercent = (savingsAmount / monthlyAnnualCost) * 100

        // Convert to Double for rounding, then to Int
        let savingsDouble = NSDecimalNumber(decimal: savingsPercent).doubleValue
        let savingsInt = max(1, min(99, Int(savingsDouble.rounded()))) // Cap between 1-99%

        // Format currency values using product's locale
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale
        formatter.maximumFractionDigits = 2

        let effectiveMonthlyFormatted = formatter.string(from: NSDecimalNumber(decimal: effectiveMonthly)) ?? ""
        let savingsFormatted = formatter.string(from: NSDecimalNumber(decimal: savingsAmount)) ?? ""

        return PricingInfo(
            hasSavings: savingsInt >= 1,
            savingsPercent: savingsInt,
            savingsAmount: savingsAmount,
            effectiveMonthlyPrice: effectiveMonthly,
            effectiveMonthlyText: "\(effectiveMonthlyFormatted)/mo",
            annualCostComparison: "Save \(savingsFormatted) per year",
        )
    }

    // MARK: - Loading & Empty Views

    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.DesignSystem.brandPink))

            Text(t.t("subscription.loading"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(Color.DesignSystem.textSecondary)
        }
        .frame(height: 150.0)
    }

    private var emptyProductsView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(Color.DesignSystem.warning)

            Text(t.t("subscription.unavailable"))
                .font(.DesignSystem.bodyLarge)
                .foregroundColor(Color.DesignSystem.textPrimary)

            if let error = storeService.error {
                Text(error.localizedDescription)
                    .font(.DesignSystem.caption)
                    .foregroundColor(Color.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(t.t("subscription.check_connection"))
                    .font(.DesignSystem.caption)
                    .foregroundColor(Color.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(t.t("common.retry")) {
                Task {
                    await storeService.forceLoadProducts()
                }
            }
            .foregroundColor(Color.DesignSystem.brandPink)
        }
        .frame(height: 180.0)
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        Button {
            Task {
                await purchase()
            }
        } label: {
            ZStack {
                // Animated gradient background
                RoundedRectangle(cornerRadius: CornerRadius.xl)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.brandPink,
                                Color.DesignSystem.brandPurple,
                                Color.DesignSystem.accentCyan,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .shadow(color: Color.DesignSystem.brandPink.opacity(0.5), radius: 20, y: 10)

                // Shimmer overlay
                #if !SKIP
                TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate

                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.3),
                            Color.clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing,
                    )
                    .offset(x: -200 + (sin(time * 2) * 200))
                    .mask(
                        RoundedRectangle(cornerRadius: CornerRadius.xl),
                    )
                }
                #endif

                // Button content
                HStack(spacing: Spacing.sm) {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.white))
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 20, weight: .bold))

                        Text(t.t("subscription.subscribe_now"))
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56.0)
            }
        }
        .disabled(selectedProduct == nil || isPurchasing || storeService.isLoading)
        .opacity(selectedProduct == nil ? 0.6 : 1.0)
        .scaleEffect(isPurchasing ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPurchasing)
        .opacity(animateHeader ? 1 : 0)
        .offset(y: animateHeader ? 0 : 30)
        .animation(
            .spring(response: 0.7, dampingFraction: 0.7)
                .delay(1.1),
            value: animateHeader,
        )
    }

    // MARK: - Legal Section (REQUIRED for App Store)

    private var legalSection: some View {
        VStack(spacing: Spacing.lg) {
            // Restore Purchases
            Button {
                Task {
                    await storeService.restorePurchases()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 16))
                    Text(t.t("subscription.restore_purchases"))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.DesignSystem.brandPink,
                            Color.DesignSystem.brandPurple,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing,
                    ),
                )
            }
            .opacity(animateHeader ? 1 : 0)
            .animation(
                .spring(response: 0.7, dampingFraction: 0.7)
                    .delay(1.2),
                value: animateHeader,
            )

            // Legal Links (REQUIRED for Guideline 3.1.2)
            HStack(spacing: Spacing.md) {
                Link(t.t("subscription.terms_of_use"), destination: URL(string: "https://foodshare.club/terms")!)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.DesignSystem.textSecondary)

                Text("·")
                    .foregroundColor(Color.DesignSystem.textTertiary)

                Link(t.t("subscription.privacy_policy"), destination: URL(string: "https://foodshare.club/privacy")!)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.DesignSystem.textSecondary)
            }
            .opacity(animateHeader ? 1 : 0)
            .animation(
                .spring(response: 0.7, dampingFraction: 0.7)
                    .delay(1.3),
                value: animateHeader,
            )

            // Subscription Terms
            Text(t.t("subscription.renewal_terms"))
                .font(.system(size: 11))
                .foregroundColor(Color.DesignSystem.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
                .opacity(animateHeader ? 1 : 0)
                .animation(
                    .spring(response: 0.7, dampingFraction: 0.7)
                        .delay(1.4),
                    value: animateHeader,
                )
        }
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xl)
    }

    // MARK: - Purchase Action

    private func purchase() async {
        guard let product = selectedProduct else {
            logger.error("Purchase attempted with no product selected")
            return
        }

        logger.info("Starting purchase flow for: \(product.id)")
        isPurchasing = true

        do {
            let transaction = try await storeService.purchase(product)
            logger.info("Purchase successful: \(transaction.id)")

            // Track successful purchase
            await trackPurchaseEvent(product: product, success: true)

            // Dismiss with slight delay for success feedback
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            dismiss()

        } catch StoreError.userCancelled {
            logger.info("Purchase cancelled by user")
            // Don't show error for user cancellation

        } catch {
            logger.error("Purchase failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true

            // Track failed purchase
            await trackPurchaseEvent(product: product, success: false, error: error)
        }

        isPurchasing = false
    }

    /// Tracks purchase events for analytics
    private func trackPurchaseEvent(product: Product, success: Bool, error: Error? = nil) async {
        // TODO: Integrate with your analytics service
        let eventName = success ? "subscription_purchase_success" : "subscription_purchase_failed"
        logger.info("Analytics: \(eventName) - \(product.id)")
    }

    // MARK: - Logging

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "SubscriptionView")

    // MARK: - Helper Methods

    /// Returns the subscription period string for a product
    private func subscriptionPeriod(for product: Product) -> String {
        storeService.subscriptionPeriod(for: product)
    }
}

// MARK: - Preview

#Preview {
    SubscriptionView()
        .environment(AppState())
}

#endif
