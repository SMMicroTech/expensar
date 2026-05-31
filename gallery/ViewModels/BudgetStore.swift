import Foundation

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
