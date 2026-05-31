import SwiftUI
import Charts
import UIKit

struct ReportsView: View {
    @EnvironmentObject private var store: ExpensesStore
    @EnvironmentObject private var syncSettings: SyncSettingsStore
    @State private var range: DashboardRange = .month
    @State private var showShare = false
    @State private var shareItems: [Any] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Range", selection: $range) {
                    ForEach(DashboardRange.allCases) { r in
                        Text(r.title).tag(r)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])

                reportSummary

                Spacer()
            }
            .navigationTitle("Reports")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { createAndSharePDFReport() }) {
                        Label("Print/Share", systemImage: "printer")
                    }
                }
            }
        }
        .sheet(isPresented: $showShare) {
            ActivityView(activityItems: shareItems)
        }
    }

    private var reportSummary: some View {
        let total = store.total(for: range.component)
        let entries = store.groupedTotals(by: range.component)
        let currency = syncSettings.currencyCode ?? Locale.current.currency?.identifier ?? "USD"

        return VStack(alignment: .leading, spacing: 12) {
            Text("Total: \(total.formatted(.currency(code: currency)))")
                .font(.title2.weight(.bold))

            if entries.isEmpty {
                Text("No data for this range")
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(entries.map { ChartItem(date: $0.date, amount: $0.amount) }) { item in
                        BarMark(
                            x: .value("Date", item.date),
                            y: .value("Amount", item.amount)
                        )
                        .foregroundStyle(Gradient(colors: [.blue, .purple]))
                    }
                }
                .frame(height: 180)
                .padding(.horizontal)

                List(entries.prefix(200), id: \.date) { item in
                    HStack {
                        Text(item.date, style: .date)
                        Spacer()
                        Text(item.amount.formatted(.currency(code: currency)))
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 200)
            }
        }
        .padding(.horizontal)
    }

    private func createAndSharePDFReport() {
        let entries = store.groupedTotals(by: range.component)
        let currency = syncSettings.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
        let total = store.total(for: range.component)

        guard let url = createPDF(entries: entries, total: total, rangeTitle: range.title, currency: currency) else { return }
        shareItems = [url]
        showShare = true
    }

    private func createPDF(entries: [(date: Date, amount: Double)], total: Double, rangeTitle: String, currency: String) -> URL? {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("report_\(Int(Date().timeIntervalSince1970)).pdf")

        do {
            try renderer.writePDF(to: tmp) { ctx in
                ctx.beginPage()
                var y: CGFloat = 24
                let title = "Report - \(rangeTitle)"
                let titleAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 20, weight: .bold)]
                title.draw(at: CGPoint(x: 24, y: y), withAttributes: titleAttr)
                y += 30

                let totalStr = "Total: \(total.formatted(.currency(code: currency)))"
                let totalAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 16, weight: .semibold)]
                totalStr.draw(at: CGPoint(x: 24, y: y), withAttributes: totalAttr)
                y += 28

                let bodyAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12, weight: .regular)]
                for item in entries {
                    let dateStr = DateFormatter.localizedString(from: item.date, dateStyle: .medium, timeStyle: .none)
                    let line = "\(dateStr) - \(item.amount.formatted(.currency(code: currency)))\n"
                    if y > page.height - 60 {
                        ctx.beginPage()
                        y = 24
                    }
                    line.draw(at: CGPoint(x: 24, y: y), withAttributes: bodyAttr)
                    y += 18
                }
            }
            return tmp
        } catch {
            return nil
        }
    }
}

private struct ChartItem: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ReportsView_Previews: PreviewProvider {
    static var previews: some View {
        ReportsView().environmentObject(ExpensesStore()).environmentObject(SyncSettingsStore())
    }
}
