import SwiftUI

struct CatPage<Content: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    Image("CatAvatar")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .catRose.opacity(0.22), radius: 10, x: 0, y: 6)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(Color.catInk)
                        if let subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(Color.catSubtext)
                        }
                    }
                }
                .padding(.top, 10)

                content
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .background(
            LinearGradient(
                colors: [.catBackground, .white, .catCream.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CatCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.catCard)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: .catRose.opacity(0.08), radius: 14, x: 0, y: 8)
    }
}

struct MetricTile: View {
    var title: String
    var value: String
    var symbolName: String
    var tint: Color

    var body: some View {
        CatCard {
            HStack {
                Image(systemName: symbolName)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Spacer()
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(Color.catSubtext)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(Color.catInk)
                .minimumScaleFactor(0.72)
                .lineLimit(1)
        }
    }
}

struct PillLabel: View {
    var text: String
    var symbolName: String?
    var tint: Color

    var body: some View {
        HStack(spacing: 6) {
            if let symbolName {
                Image(systemName: symbolName)
            }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }
}

struct EmptyStateView: View {
    var title: String
    var message: String
    var symbolName: String

    var body: some View {
        CatCard {
            VStack(alignment: .center, spacing: 12) {
                Image(systemName: symbolName)
                    .font(.system(size: 38))
                    .foregroundStyle(Color.catRose)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.catInk)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.catSubtext)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
    }
}

struct SectionHeader: View {
    var title: String
    var actionTitle: String?
    var action: (() -> Void)?

    init(_ title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Color.catInk)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.catRose)
            }
        }
    }
}
