import Foundation
import SwiftUI
import UIKit

final class ExpensesStore: ObservableObject {
    @Published private(set) var expenses: [Expense] = []
    @Published var yearWrapUp: YearWrapUp?

    private let fileURL: URL
    private let imagesDir: URL
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let lastWrapUpYear = "expenses.lastWrapUpYear"
    }

    init() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent("expenses.json")
        self.imagesDir = docs.appendingPathComponent("images")
        if !fm.fileExists(atPath: imagesDir.path) {
            try? fm.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        }
        load()        checkYearWrapUp()    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([Expense].self, from: data)
            self.expenses = decoded.sorted { $0.date > $1.date }
        } catch {
            print("Failed to load expenses:", error)
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(expenses)
            try data.write(to: fileURL, options: [.atomicWrite])
        } catch {
            print("Failed to save expenses:", error)
        }
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
        var photoFilename: String? = nil
        if let image = image, let data = image.jpegData(compressionQuality: 0.8) {
            let fname = "img_\(UUID().uuidString).jpg"
            let url = imagesDir.appendingPathComponent(fname)
            try? data.write(to: url)
            photoFilename = fname
        }

        let expense = Expense(
            title: title,
            details: details,
            amount: amount,
            date: Date(),
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
        for idx in offsets {
            if let fname = expenses[idx].photoFilename {
                let url = imagesDir.appendingPathComponent(fname)
                try? FileManager.default.removeItem(at: url)
            }
        }
        expenses.remove(atOffsets: offsets)
        save()
    }

    func image(for filename: String?) -> UIImage? {
        guard let filename = filename else { return nil }
        let url = imagesDir.appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }

    // Aggregation helpers
    func totalAmount() -> Double {
        expenses.reduce(0) { $0 + $1.amount }
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

        return groups
            .map { (date: $0.key, amount: $0.value) }
            .sorted { $0.date > $1.date }
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
        }.reduce(0) { $0 + $1.amount }
    }

    func total(forYear year: Int) -> Double {
        let calendar = Calendar.current
        return expenses.filter { calendar.component(.year, from: $0.date) == year }
            .reduce(0) { $0 + $1.amount }
    }

    private func checkYearWrapUp() {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let storedYear = defaults.integer(forKey: Keys.lastWrapUpYear)

        if storedYear == 0 {
            defaults.set(currentYear, forKey: Keys.lastWrapUpYear)
            return
        }

        if storedYear != currentYear {
            let previousYearExpenses = expenses.filter { calendar.component(.year, from: $0.date) == storedYear }
            if !previousYearExpenses.isEmpty {
                let total = previousYearExpenses.reduce(0) { $0 + $1.amount }
                yearWrapUp = YearWrapUp(
                    year: storedYear,
                    total: total,
                    expenseCount: previousYearExpenses.count,
                    averageExpense: total / Double(previousYearExpenses.count)
                )
            }
            defaults.set(currentYear, forKey: Keys.lastWrapUpYear)
        }
    }
}

struct YearWrapUp: Identifiable {
    let id = UUID()
    let year: Int
    let total: Double
    let expenseCount: Int
    let averageExpense: Double
}
