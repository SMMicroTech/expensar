import SwiftUI

struct MetricCard: View {
    let title: String
    let amount: Double
    let systemImage: String
    let tint: Color
    var isCount: Bool = false
    var currencyCode: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
                .padding(10)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(displayValue)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    private var displayValue: String {
        if isCount {
            return Int(amount).formatted()
        }
        let code = currencyCode ?? Locale.current.currency?.identifier ?? "USD"
        return amount.formatted(.currency(code: code))
    }
}
