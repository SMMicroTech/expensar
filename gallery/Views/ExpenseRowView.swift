import SwiftUI

struct ExpenseRowView: View {
    @EnvironmentObject private var syncSettings: SyncSettingsStore
    let expense: Expense
    let image: UIImage?

    private var currencyCode: String {
        syncSettings.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
                    .frame(width: 72, height: 72)
                    .overlay(Image(systemName: "doc.text.image").foregroundColor(Color.accentColor))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(expense.title)
                        .font(.headline)
                    Spacer()
                    Text(expense.formattedAmount(currencyCode: currencyCode))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Text(expense.details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Label(expense.paymentMethod.rawValue, systemImage: expense.paymentMethod == .cash ? "banknote" : "creditcard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let location = expense.locationName {
                        Label(location, systemImage: "location")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(14)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }
}
