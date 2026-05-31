import SwiftUI
import UIKit

extension Notification.Name {
    static let openAddExpenseFromSharedImage = Notification.Name("openAddExpenseFromSharedImage")
    static let openAddExpenseFromSharePayload = Notification.Name("openAddExpenseFromSharePayload")
}

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showYearWrapUp = false
    @EnvironmentObject private var store: ExpensesStore
    @EnvironmentObject private var budgetStore: BudgetStore

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tag(0)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.xaxis")
                }

            ExpensesListView()
                .tag(1)
                .tabItem {
                    Label("Expenses", systemImage: "wallet.pass.fill")
                }

            ReportsView()
                .tag(2)
                .tabItem {
                    Label("Reports", systemImage: "printer")
                }

            ConfigView()
                .tag(3)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .onOpenURL { url in
            handleIncomingShareURL(url)
        }
        .onAppear {
            store.refreshYearWrapUp()
            showYearWrapUp = store.yearWrapUp != nil
        }
        .sheet(isPresented: $showYearWrapUp) {
            if let wrapUp = store.yearWrapUp {
                YearlyWrapUpView(wrapUp: wrapUp) {
                    store.yearWrapUp = nil
                    showYearWrapUp = false
                }
            } else {
                EmptyView()
            }
        }
    }

    private func handleIncomingShareURL(_ url: URL) {
        guard url.scheme?.lowercased() == "expensar" else { return }

        var sharedImage: UIImage?
        var sharedTitle: String?
        var sharedText: String?
        var sharedAmount: String?

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if let imagePath = components?.queryItems?.first(where: { $0.name == "imagePath" })?.value {
            let decodedPath = imagePath.removingPercentEncoding ?? imagePath
            sharedImage = UIImage(contentsOfFile: decodedPath)
        } else if let imageFileURLValue = components?.queryItems?.first(where: { $0.name == "imageFileURL" })?.value,
                  let fileURL = URL(string: imageFileURLValue),
                  fileURL.isFileURL,
                  let data = try? Data(contentsOf: fileURL) {
            sharedImage = UIImage(data: data)
        }

        sharedTitle = components?.queryItems?.first(where: { $0.name == "sharedTitle" })?.value
        sharedText = components?.queryItems?.first(where: { $0.name == "sharedText" })?.value
        sharedAmount = components?.queryItems?.first(where: { $0.name == "sharedAmount" })?.value

        NotificationCenter.default.post(
            name: .openAddExpenseFromSharePayload,
            object: nil,
            userInfo: [
                "image": sharedImage as Any,
                "title": sharedTitle as Any,
                "details": sharedText as Any,
                "amount": sharedAmount as Any
            ]
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ExpensesStore())
            .environmentObject(SyncSettingsStore())
            .environmentObject(BudgetStore())
    }
}
