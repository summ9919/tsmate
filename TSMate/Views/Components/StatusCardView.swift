import SwiftUI

struct StatusCardView: View {
    let card: StatusCard

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: card.icon.symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(card.icon.tint)
                Text(card.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text(card.detail)
                .font(.system(size: 10.5))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.brand)
        )
    }
}

struct StatusCardGrid: View {
    let cards: [StatusCard]

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(cards) { card in
                StatusCardView(card: card)
            }
        }
    }
}
