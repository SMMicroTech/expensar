import Foundation

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

    var formattedAmount: String {
        amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
}
