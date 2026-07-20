import SwiftUI

/// One-time Pro unlock sheet. States the exact value exchange, the price,
/// one-time billing (no subscription, no trial countdown, no renewal), and
/// restore. Free core stays fully usable behind it — no dark patterns.
struct PaywallView: View {
    enum Trigger {
        case gearLimit
        case multiGearCompare
        case export

        var headline: String {
            switch self {
            case .gearLimit: return "Keep more than one gear profile"
            case .multiGearCompare: return "Compare across gear profiles"
            case .export: return "Take your data with you"
            }
        }
    }

    @EnvironmentObject var pro: ProStore
    let trigger: Trigger
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(trigger.headline)
                        .font(.title2).fontWeight(.bold)
                        .foregroundColor(Theme.ink)
                    Text("The free tier already records sessions, diagnoses groups, and aligns one gear's tuning history — nothing here is held hostage. Pro is a one-time unlock for heavier use:")
                        .font(.subheadline)
                        .foregroundColor(Theme.inkSoft)
                    benefitRow("square.and.arrow.up", "JSON and CSV export of everything on this device")
                    benefitRow("wrench.and.screwdriver", "Unlimited gear profiles")
                    benefitRow("timeline.selection", "Cross-gear attribution comparison")
                    pricingBlock
                    if let error = pro.purchaseError {
                        StatusBar(kind: .failure, text: error)
                    }
                    if pro.storeUnavailable && !pro.isPro {
                        StatusBar(kind: .info, text: "The store is unavailable right now. Purchase and restore return here as soon as it responds.")
                    }
                    purchaseButtons
                    Text("One-time purchase. No subscription, no trial clock, no renewal. Cancel anytime before confirming in the App Store sheet; Apple handles refunds.")
                        .font(.caption)
                        .foregroundColor(Theme.inkSoft)
                }
                .padding()
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("ArrowTune Pro")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Not now") { isPresented = false }
                        .accessibilityHint("Closes this sheet; the free tier stays fully usable")
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func benefitRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(Theme.signal)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundColor(Theme.ink)
        }
        .accessibilityElement(children: .combine)
    }

    private var pricingBlock: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pro unlock")
                    .font(.headline)
                    .foregroundColor(Theme.ink)
                Text("One-time purchase, permanent")
                    .font(.caption)
                    .foregroundColor(Theme.inkSoft)
            }
            Spacer()
            Text(pro.displayPrice ?? "—")
                .font(.system(.title3, design: .monospaced).monospacedDigit())
                .foregroundColor(Theme.signal)
        }
        .padding(12)
        .background(Theme.cardGround)
        .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pro unlock, one-time purchase, \(pro.displayPrice ?? "price unavailable")")
    }

    private var purchaseButtons: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    await pro.purchase()
                    if pro.isPro { isPresented = false }
                }
            } label: {
                HStack {
                    if pro.purchaseInFlight { ProgressView().tint(.white) }
                    Text(pro.displayPrice.map { "Buy once — \($0)" } ?? "Buy Pro once")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.signal)
                .foregroundColor(.white)
            }
            .disabled(pro.purchaseInFlight)
            .accessibilityHint("Starts the one-time App Store purchase")
            Button("Restore purchase") {
                Task {
                    await pro.restore()
                    if pro.isPro { isPresented = false }
                }
            }
            .foregroundColor(Theme.ink)
            .disabled(pro.purchaseInFlight)
        }
    }
}
