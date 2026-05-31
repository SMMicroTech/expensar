import SwiftUI

struct YearlyWrapUpView: View {
    let wrapUp: YearWrapUp
    let dismissAction: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Yearly Wrap-Up")
                    .font(.largeTitle.weight(.bold))

                Text("\(wrapUp.year) Summary")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(spacing: 14) {
                    SummaryRow(title: "Total spent", value: wrapUp.total.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
                    SummaryRow(title: "Expense count", value: String(wrapUp.expenseCount))
                    SummaryRow(title: "Average per expense", value: wrapUp.averageExpense.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                Text("A fresh year has started — your previous year’s spending has been wrapped up for review.")
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismissAction()
                    }
                }
            }
        }
    }
}

private struct SummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}
