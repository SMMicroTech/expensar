import SwiftUI

struct ConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var syncSettings: SyncSettingsStore
    @State private var pendingProvider: CloudSyncProvider?
    @State private var showAuthCompleteDialog = false
    @State private var iCloudStatusMessage: String?
    @EnvironmentObject private var budgetStore: BudgetStore
    @EnvironmentObject private var store: ExpensesStore
    @State private var monthlyTargetText: String = ""
    @State private var selectedCurrency: String = ""
    @State private var googleSheetURLText: String = ""
    @State private var exportStatusMessage: String?
    @State private var selectedArchive: ExpenseArchive?

    var body: some View {
        NavigationStack {
            Form {
                Section("Configuration") {
                    Label("Default currency: LKR", systemImage: "banknote")
                    Label("Long press expense for details", systemImage: "hand.tap")
                    Label("Tap expense to open Maps", systemImage: "map")
                }

                Section("Sync Data DB") {
                    HStack {
                        Label("Google Drive", systemImage: "externaldrive.badge.icloud")
                        Spacer()
                        authStatusView(isAuthorized: syncSettings.googleDriveAuthorized)
                    }

                    HStack {
                        Button(syncSettings.googleDriveAuthorized ? "Re-authorize" : "Authorize") {
                            pendingProvider = .googleDrive
                            if let url = googleDriveAuthURL() {
                                openURL(url)
                            }
                            showAuthCompleteDialog = true
                        }

                        Spacer()

                        Button("Use for Sync") {
                            syncSettings.selectedProvider = .googleDrive
                        }
                        .disabled(!syncSettings.googleDriveAuthorized)
                    }

                    if syncSettings.googleDriveAuthorized {
                        Button("Disconnect Google Drive", role: .destructive) {
                            syncSettings.disconnect(.googleDrive)
                        }
                    }
                }

                Section("Dropbox") {
                    HStack {
                        Label("Dropbox", systemImage: "shippingbox")
                        Spacer()
                        authStatusView(isAuthorized: syncSettings.dropboxAuthorized)
                    }

                    HStack {
                        Button(syncSettings.dropboxAuthorized ? "Re-authorize" : "Authorize") {
                            pendingProvider = .dropbox
                            if let url = dropboxAuthURL() {
                                openURL(url)
                            }
                            showAuthCompleteDialog = true
                        }

                        Spacer()

                        Button("Use for Sync") {
                            syncSettings.selectedProvider = .dropbox
                        }
                        .disabled(!syncSettings.dropboxAuthorized)
                    }

                    if syncSettings.dropboxAuthorized {
                        Button("Disconnect Dropbox", role: .destructive) {
                            syncSettings.disconnect(.dropbox)
                        }
                    }
                }

                Section("iCloud") {
                    HStack {
                        Label("iCloud", systemImage: "icloud")
                        Spacer()
                        authStatusView(isAuthorized: syncSettings.iCloudAuthorized)
                    }

                    HStack {
                        Button("Check iCloud Authorization") {
                            syncSettings.iCloudAuthorized = isICloudAvailable()
                            iCloudStatusMessage = syncSettings.iCloudAuthorized
                                ? "iCloud account is available for this device."
                                : "iCloud is not available. Sign in to iCloud in Settings."
                        }

                        Spacer()

                        Button("Use for Sync") {
                            syncSettings.selectedProvider = .iCloud
                        }
                        .disabled(!syncSettings.iCloudAuthorized)
                    }

                    if syncSettings.iCloudAuthorized {
                        Button("Disconnect iCloud", role: .destructive) {
                            syncSettings.disconnect(.iCloud)
                        }
                    }

                    if let iCloudStatusMessage {
                        Text(iCloudStatusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Budget") {
                    HStack {
                        Text("Monthly target")
                        Spacer()
                        TextField("Amount", text: $monthlyTargetText)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 120)
                    }

                    Button("Save target") {
                        if let val = Double(monthlyTargetText) {
                            budgetStore.monthlyTarget = val
                        } else {
                            budgetStore.monthlyTarget = nil
                        }
                    }
                }

                Section("Google Sheets") {
                    TextField("Google Apps Script webhook URL", text: $googleSheetURLText)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocapitalization(.none)

                    Button("Save Google Sheets URL") {
                        syncSettings.googleSheetURL = googleSheetURLText.isEmpty ? nil : googleSheetURLText
                    }
                    .disabled(googleSheetURLText.isEmpty)

                    Button("Send expenses to Google Sheets") {
                        exportToGoogleSheets()
                    }
                    .disabled(syncSettings.googleSheetURL?.isEmpty ?? true || store.expenses.isEmpty)

                    if let exportStatusMessage {
                        Text(exportStatusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Currency") {
                    let currencies = ["USD","EUR","GBP","LKR","JPY","CNY","INR"]
                    Picker("Currency code", selection: $selectedCurrency) {
                        ForEach(currencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                        Text("Other...").tag("")
                    }
                    .onAppear {
                        selectedCurrency = syncSettings.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
                        monthlyTargetText = budgetStore.monthlyTarget.map { String($0) } ?? ""
                        googleSheetURLText = syncSettings.googleSheetURL ?? ""
                    }

                    HStack {
                        Text("Custom code")
                        Spacer()
                        TextField("e.g. USD", text: $selectedCurrency)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }

                    Button("Save currency") {
                        syncSettings.currencyCode = selectedCurrency.isEmpty ? nil : selectedCurrency
                    }
                }

                Section("Current Sync Target") {
                    Text(syncSettings.selectedProvider?.rawValue ?? "None")
                        .foregroundStyle(.secondary)
                }

                Section("Archives") {
                    if store.archives.isEmpty {
                        Text("No archived years yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.archives) { archive in
                            Button {
                                selectedArchive = archive
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(archive.year) Archive")
                                            .font(.headline)
                                        Text("\(archive.expenseCount) expenses")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Text(archive.total.formatted(.currency(code: syncSettings.currencyCode ?? Locale.current.currency?.identifier ?? "USD")))
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Config")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                }
            }
            .confirmationDialog("Complete authorization", isPresented: $showAuthCompleteDialog, titleVisibility: .visible) {
                Button("Mark as Authorized") {
                    if let pendingProvider {
                        syncSettings.markAuthorized(pendingProvider)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("After signing in on the provider page, tap Mark as Authorized.")
            }
            .sheet(item: $selectedArchive) { archive in
                YearlyWrapUpView(wrapUp: archive.summary) {
                    selectedArchive = nil
                }
            }
        }
    }

    @ViewBuilder
    private func authStatusView(isAuthorized: Bool) -> some View {
        Text(isAuthorized ? "Authorized" : "Not Authorized")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isAuthorized ? Color.green.opacity(0.18) : Color.gray.opacity(0.18), in: Capsule())
            .foregroundStyle(isAuthorized ? Color.green : Color.secondary)
    }

    private func googleDriveAuthURL() -> URL? {
        let clientID = "YOUR_GOOGLE_CLIENT_ID"
        let redirectURI = "https://localhost"
        let scope = "https://www.googleapis.com/auth/drive.file"
        let auth = "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(clientID)&redirect_uri=\(redirectURI)&response_type=code&scope=\(scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scope)&access_type=offline&prompt=consent"
        return URL(string: auth)
    }

    private func dropboxAuthURL() -> URL? {
        let clientID = "YOUR_DROPBOX_APP_KEY"
        let redirectURI = "https://localhost"
        let auth = "https://www.dropbox.com/oauth2/authorize?client_id=\(clientID)&response_type=code&redirect_uri=\(redirectURI)"
        return URL(string: auth)
    }

    private func isICloudAvailable() -> Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private func saveSettings() {
        if selectedCurrency.isEmpty {
            syncSettings.currencyCode = nil
        } else {
            syncSettings.currencyCode = selectedCurrency
        }

        if let value = Double(monthlyTargetText) {
            budgetStore.monthlyTarget = value
        } else {
            budgetStore.monthlyTarget = nil
        }

        syncSettings.googleSheetURL = googleSheetURLText.isEmpty ? nil : googleSheetURLText
    }

    private func exportToGoogleSheets() {
        guard let urlString = syncSettings.googleSheetURL,
              let url = URL(string: urlString) else {
            exportStatusMessage = "Invalid Google Sheets URL."
            return
        }

        let rows = store.expenses.map { expense in
            [
                DateFormatter.localizedString(from: expense.date, dateStyle: .medium, timeStyle: .short),
                expense.title,
                expense.details,
                expense.formattedAmount(currencyCode: syncSettings.currencyCode),
                expense.paymentMethod.rawValue,
                expense.locationName ?? "",
                expense.latitude.map { String($0) } ?? "",
                expense.longitude.map { String($0) } ?? ""
            ]
        }

        let payload: [String: Any] = [
            "rows": rows,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            exportStatusMessage = "Unable to encode expense data."
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        exportStatusMessage = "Sending expenses..."

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    exportStatusMessage = "Export failed: \(error.localizedDescription)"
                    return
                }

                if let httpResponse = response as? HTTPURLResponse,
                   200..<300 ~= httpResponse.statusCode {
                    exportStatusMessage = "Expenses exported successfully."
                } else {
                    exportStatusMessage = "Google Sheets export failed."
                }
            }
        }.resume()
    }
}
