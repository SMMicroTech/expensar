import SwiftUI
import UIKit
import CoreLocation
import Combine
import Speech
import AVFoundation

enum CloudSyncProvider: String, Codable, CaseIterable, Identifiable {
    case googleDrive = "Google Drive"
    case dropbox = "Dropbox"
    case iCloud = "iCloud"

    var id: String { rawValue }
}

struct ExpenseTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var category: String
    var defaultAmount: Double?
    var defaultPaymentMethod: Expense.PaymentMethod
    var defaultLocationName: String?

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        defaultAmount: Double? = nil,
        defaultPaymentMethod: Expense.PaymentMethod = .cash,
        defaultLocationName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.defaultAmount = defaultAmount
        self.defaultPaymentMethod = defaultPaymentMethod
        self.defaultLocationName = defaultLocationName
    }
}

struct Expense: Identifiable, Codable {
    enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
        case cash = "Cash"
        case card = "Card"

        var id: String { rawValue }
    }

    let id: UUID
    var title: String
    var details: String
    var amount: Double
    var date: Date
    var paymentMethod: PaymentMethod
    var photoFilename: String?
    var locationName: String?
    var latitude: Double?
    var longitude: Double?

    init(
        id: UUID = UUID(),
        title: String,
        details: String,
        amount: Double,
        date: Date = Date(),
        paymentMethod: PaymentMethod = .cash,
        photoFilename: String? = nil,
        locationName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.amount = amount
        self.date = date
        self.paymentMethod = paymentMethod
        self.photoFilename = photoFilename
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
    }

    func formattedAmount(currencyCode: String? = nil) -> String {
        let code = currencyCode ?? Locale.current.currency?.identifier ?? "USD"
        return amount.formatted(.currency(code: code))
    }

    var formattedAmount: String {
        formattedAmount(currencyCode: nil)
    }
}

final class ExpensesStore: ObservableObject {
    @Published private(set) var expenses: [Expense] = []
    @Published private(set) var templates: [ExpenseTemplate] = []
    @Published private(set) var templateUsageCounts: [UUID: Int] = [:]
    @Published private(set) var archives: [ExpenseArchive] = []
    @Published var yearWrapUp: YearWrapUp?

    private let fileURL: URL
    private let templatesURL: URL
    private let templateUsageURL: URL
    private let archivesURL: URL
    private let imagesDir: URL
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let lastWrapUpYear = "expenses.lastWrapUpYear"
    }

    init() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("expenses.json")
        templatesURL = docs.appendingPathComponent("templates.json")
        templateUsageURL = docs.appendingPathComponent("templateUsage.json")
        archivesURL = docs.appendingPathComponent("expenseArchives.json")
        imagesDir = docs.appendingPathComponent("images")
        if !fm.fileExists(atPath: imagesDir.path) {
            try? fm.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        }
        load()
        loadTemplates()
        loadTemplateUsage()
        loadArchives()
        checkYearWrapUp()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            expenses = try JSONDecoder().decode([Expense].self, from: data).sorted { $0.date > $1.date }
        } catch {
            print("Failed to load expenses:", error)
        }
    }

    func loadTemplates() {
        guard FileManager.default.fileExists(atPath: templatesURL.path) else { return }
        do {
            let data = try Data(contentsOf: templatesURL)
            templates = try JSONDecoder().decode([ExpenseTemplate].self, from: data)
        } catch {
            print("Failed to load templates:", error)
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(expenses)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("Failed to save expenses:", error)
        }
    }

    func saveTemplates() {
        do {
            let data = try JSONEncoder().encode(templates)
            try data.write(to: templatesURL, options: [.atomic])
        } catch {
            print("Failed to save templates:", error)
        }
    }

    func loadTemplateUsage() {
        guard FileManager.default.fileExists(atPath: templateUsageURL.path) else { return }
        do {
            let data = try Data(contentsOf: templateUsageURL)
            let raw = try JSONDecoder().decode([String: Int].self, from: data)
            var mapped: [UUID: Int] = [:]
            for (key, value) in raw {
                if let id = UUID(uuidString: key) {
                    mapped[id] = value
                }
            }
            templateUsageCounts = mapped
        } catch {
            print("Failed to load template usage:", error)
        }
    }

    func saveTemplateUsage() {
        do {
            let raw = Dictionary(uniqueKeysWithValues: templateUsageCounts.map { ($0.key.uuidString, $0.value) })
            let data = try JSONEncoder().encode(raw)
            try data.write(to: templateUsageURL, options: [.atomic])
        } catch {
            print("Failed to save template usage:", error)
        }
    }

    func loadArchives() {
        guard FileManager.default.fileExists(atPath: archivesURL.path) else { return }
        do {
            let data = try Data(contentsOf: archivesURL)
            archives = try JSONDecoder().decode([ExpenseArchive].self, from: data).sorted { $0.year > $1.year }
        } catch {
            print("Failed to load archives:", error)
        }
    }

    func saveArchives() {
        do {
            let data = try JSONEncoder().encode(archives)
            try data.write(to: archivesURL, options: [.atomic])
        } catch {
            print("Failed to save archives:", error)
        }
    }

    func addTemplate(_ template: ExpenseTemplate) {
        templates.append(template)
        saveTemplates()
    }

    func deleteTemplate(_ template: ExpenseTemplate) {
        templates.removeAll { $0.id == template.id }
        templateUsageCounts[template.id] = nil
        saveTemplates()
        saveTemplateUsage()
    }

    func markTemplateUsed(_ template: ExpenseTemplate) {
        templateUsageCounts[template.id, default: 0] += 1
        saveTemplateUsage()
    }

    func usageCount(for template: ExpenseTemplate) -> Int {
        templateUsageCounts[template.id, default: 0]
    }

    func frequentTemplates(limit: Int = 5) -> [ExpenseTemplate] {
        templates
            .filter { templateUsageCounts[$0.id, default: 0] > 0 }
            .sorted {
                let lhs = templateUsageCounts[$0.id, default: 0]
                let rhs = templateUsageCounts[$1.id, default: 0]
                if lhs == rhs {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return lhs > rhs
            }
            .prefix(limit)
            .map { $0 }
    }

    func addExpense(
        title: String,
        details: String,
        amount: Double,
        paymentMethod: Expense.PaymentMethod,
        image: UIImage?,
        locationName: String?,
        latitude: Double?,
        longitude: Double?
    ) {
        archiveCompletedYearsIfNeeded()

        var photoFilename: String?
        if let image, let data = image.jpegData(compressionQuality: 0.82) {
            let filename = "img_\(UUID().uuidString).jpg"
            let url = imagesDir.appendingPathComponent(filename)
            try? data.write(to: url)
            photoFilename = filename
        }

        let expense = Expense(
            title: title,
            details: details,
            amount: amount,
            paymentMethod: paymentMethod,
            photoFilename: photoFilename,
            locationName: locationName,
            latitude: latitude,
            longitude: longitude
        )
        expenses.insert(expense, at: 0)
        save()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            if let filename = expenses[index].photoFilename {
                try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(filename))
            }
        }
        expenses.remove(atOffsets: offsets)
        save()
    }

    func image(for filename: String?) -> UIImage? {
        guard let filename else { return nil }
        return UIImage(contentsOfFile: imagesDir.appendingPathComponent(filename).path)
    }

    func groupedTotals(by component: Calendar.Component) -> [(date: Date, amount: Double)] {
        let calendar = Calendar.current
        var groups: [Date: Double] = [:]

        for expense in expenses {
            let keyDate: Date
            switch component {
            case .day:
                keyDate = calendar.startOfDay(for: expense.date)
            case .weekOfYear:
                keyDate = calendar.dateInterval(of: .weekOfYear, for: expense.date)?.start ?? calendar.startOfDay(for: expense.date)
            case .month:
                keyDate = calendar.dateInterval(of: .month, for: expense.date)?.start ?? calendar.startOfDay(for: expense.date)
            default:
                keyDate = calendar.startOfDay(for: expense.date)
            }
            groups[keyDate, default: 0] += expense.amount
        }

        return groups.map { (date: $0.key, amount: $0.value) }.sorted { $0.date > $1.date }
    }

    func total(for component: Calendar.Component) -> Double {
        let calendar = Calendar.current
        return expenses.filter { expense in
            switch component {
            case .day:
                return calendar.isDateInToday(expense.date)
            case .weekOfYear:
                return calendar.isDate(expense.date, equalTo: Date(), toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(expense.date, equalTo: Date(), toGranularity: .month)
            case .year:
                return calendar.isDate(expense.date, equalTo: Date(), toGranularity: .year)
            default:
                return true
            }
        }
        .reduce(0) { $0 + $1.amount }
    }

    func total(forYear year: Int) -> Double {
        let calendar = Calendar.current
        return expenses.filter { calendar.component(.year, from: $0.date) == year }
            .reduce(0) { $0 + $1.amount }
    }

    func refreshYearWrapUp() {
        archiveCompletedYearsIfNeeded()
    }

    func archiveCompletedYearsIfNeeded() {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let yearsInActiveStore = Set(expenses.map { calendar.component(.year, from: $0.date) })
        let archivalYears = yearsInActiveStore.filter { $0 != currentYear }

        guard !archivalYears.isEmpty else {
            defaults.set(currentYear, forKey: Keys.lastWrapUpYear)
            return
        }

        var latestWrapUp: YearWrapUp?
        var updatedArchives = archives

        for year in archivalYears.sorted() {
            let yearExpenses = expenses.filter { calendar.component(.year, from: $0.date) == year }
            guard !yearExpenses.isEmpty else { continue }
            let archive = ExpenseArchive(year: year, archivedAt: Date(), expenses: yearExpenses.sorted { $0.date > $1.date })
            if !updatedArchives.contains(where: { $0.year == year }) {
                updatedArchives.append(archive)
            }
            latestWrapUp = archive.summary
        }

        archives = updatedArchives.sorted { $0.year > $1.year }
        expenses.removeAll { archivalYears.contains(calendar.component(.year, from: $0.date)) }
        save()
        saveArchives()
        defaults.set(currentYear, forKey: Keys.lastWrapUpYear)
        yearWrapUp = latestWrapUp
    }
}

struct ExpenseArchive: Identifiable, Codable {
    let id: UUID
    let year: Int
    let archivedAt: Date
    let expenses: [Expense]

    init(id: UUID = UUID(), year: Int, archivedAt: Date = Date(), expenses: [Expense]) {
        self.id = id
        self.year = year
        self.archivedAt = archivedAt
        self.expenses = expenses
    }

    var total: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    var expenseCount: Int {
        expenses.count
    }

    var averageExpense: Double {
        guard !expenses.isEmpty else { return 0 }
        return total / Double(expenses.count)
    }

    var summary: YearWrapUp {
        YearWrapUp(year: year, total: total, expenseCount: expenseCount, averageExpense: averageExpense)
    }
}

struct YearWrapUp: Identifiable {
    let id = UUID()
    let year: Int
    let total: Double
    let expenseCount: Int
    let averageExpense: Double
}

final class SyncSettingsStore: ObservableObject {
    @Published var googleDriveAuthorized: Bool {
        didSet { defaults.set(googleDriveAuthorized, forKey: Keys.googleDriveAuthorized) }
    }

    @Published var dropboxAuthorized: Bool {
        didSet { defaults.set(dropboxAuthorized, forKey: Keys.dropboxAuthorized) }
    }

    @Published var iCloudAuthorized: Bool {
        didSet { defaults.set(iCloudAuthorized, forKey: Keys.iCloudAuthorized) }
    }

    @Published var selectedProvider: CloudSyncProvider? {
        didSet { defaults.set(selectedProvider?.rawValue, forKey: Keys.selectedProvider) }
    }

    @Published var currencyCode: String? {
        didSet { defaults.set(currencyCode, forKey: Keys.currencyCode) }
    }

    @Published var googleSheetURL: String? {
        didSet { defaults.set(googleSheetURL, forKey: Keys.googleSheetURL) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let googleDriveAuthorized = "sync.googleDriveAuthorized"
        static let dropboxAuthorized = "sync.dropboxAuthorized"
        static let iCloudAuthorized = "sync.iCloudAuthorized"
        static let selectedProvider = "sync.selectedProvider"
        static let currencyCode = "settings.currencyCode"
        static let googleSheetURL = "settings.googleSheetURL"
    }

    init() {
        googleDriveAuthorized = defaults.bool(forKey: Keys.googleDriveAuthorized)
        dropboxAuthorized = defaults.bool(forKey: Keys.dropboxAuthorized)
        iCloudAuthorized = defaults.bool(forKey: Keys.iCloudAuthorized)

        if let raw = defaults.string(forKey: Keys.selectedProvider),
           let provider = CloudSyncProvider(rawValue: raw) {
            selectedProvider = provider
        } else {
            selectedProvider = nil
        }

        if let code = defaults.string(forKey: Keys.currencyCode) {
            currencyCode = code
        } else {
            currencyCode = nil
        }

        if let url = defaults.string(forKey: Keys.googleSheetURL) {
            googleSheetURL = url
        } else {
            googleSheetURL = nil
        }
    }

    func markAuthorized(_ provider: CloudSyncProvider) {
        switch provider {
        case .googleDrive:
            googleDriveAuthorized = true
        case .dropbox:
            dropboxAuthorized = true
        case .iCloud:
            iCloudAuthorized = true
        }
    }

    func disconnect(_ provider: CloudSyncProvider) {
        switch provider {
        case .googleDrive:
            googleDriveAuthorized = false
        case .dropbox:
            dropboxAuthorized = false
        case .iCloud:
            iCloudAuthorized = false
        }

        if selectedProvider == provider {
            selectedProvider = nil
        }
    }

    func canUseForSync(_ provider: CloudSyncProvider) -> Bool {
        switch provider {
        case .googleDrive:
            return googleDriveAuthorized
        case .dropbox:
            return dropboxAuthorized
        case .iCloud:
            return iCloudAuthorized
        }
    }
}

final class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()
    @Published var lastLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermissionAndLocation() {
        manager.requestWhenInUseAuthorization()
        if CLLocationManager.locationServicesEnabled() {
            manager.requestLocation()
        }
    }

    func requestCurrentLocation() {
        if CLLocationManager.locationServicesEnabled() {
            manager.requestLocation()
        }
    }
}

enum VoiceFieldTarget: String, CaseIterable, Identifiable {
    case title = "Title"
    case description = "Description"
    case amount = "Amount"

    var id: String { rawValue }
}

enum VoicePlacementMode: String, CaseIterable, Identifiable {
    case command = "Command"
    case manual = "Manual"

    var id: String { rawValue }
}

final class VoiceCaptureManager: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var latestFinalUtterance: String = ""
    @Published var statusMessage: String = "Ready"

    private let recognizer = SFSpeechRecognizer(locale: Locale.current)
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }

    func toggleListening() {
        isListening ? stopListening() : startListening()
    }

    func startListening() {
        guard !audioEngine.isRunning else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            request = SFSpeechAudioBufferRecognitionRequest()
            request?.shouldReportPartialResults = true

            guard let request = request else {
                statusMessage = "Voice request unavailable"
                return
            }

            let inputNode = audioEngine.inputNode
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNode.outputFormat(forBus: 0)) { buffer, _ in
                request.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            statusMessage = "Listening..."
            isListening = true

            recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }

                if let result {
                    if result.isFinal {
                        DispatchQueue.main.async {
                            self.latestFinalUtterance = result.bestTranscription.formattedString
                        }
                    }
                }

                if error != nil {
                    self.stopListening()
                }
            }
        } catch {
            statusMessage = "Voice unavailable"
            stopListening()
        }
    }

    func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        request?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        isListening = false
        if statusMessage == "Listening..." {
            statusMessage = "Stopped"
        }
    }
    
}

// MARK: - BudgetStore
final class BudgetStore: ObservableObject {
    @Published var monthlyTarget: Double? {
        didSet {
            if let val = monthlyTarget {
                UserDefaults.standard.set(val, forKey: Keys.monthlyTarget)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.monthlyTarget)
            }
        }
    }

    private enum Keys {
        static let monthlyTarget = "budget.monthlyTarget"
    }

    init() {
        if UserDefaults.standard.object(forKey: Keys.monthlyTarget) != nil {
            monthlyTarget = UserDefaults.standard.double(forKey: Keys.monthlyTarget)
        } else {
            monthlyTarget = nil
        }
    }
}


extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            requestCurrentLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.first?.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error)
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

enum DashboardRange: String, CaseIterable, Identifiable {
    case day = "Daily"
    case week = "Weekly"
    case month = "Monthly"
    case year = "Yearly"

    var id: String { rawValue }
    var title: String { rawValue }

    var subtitle: String {
        switch self {
        case .day: return "Today"
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        }
    }

    var component: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }
}
