import SwiftUI
import CoreLocation

struct AddExpenseView: View {
    @EnvironmentObject private var store: ExpensesStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @StateObject private var voiceManager = VoiceCaptureManager()

    @State private var title = ""
    @State private var details = ""
    @State private var amount = ""
    @State private var paymentMethod: Expense.PaymentMethod = .cash
    @State private var locationText = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var resolvingLocation = false
    @State private var showTemplatePickerSheet = false
    @State private var showSaveAsTemplateInput = false
    @State private var templateNameInput = ""
    @State private var templateCategoryInput = ""
    @State private var didApplyInitialImage = false
    @State private var didApplyInitialSharePayload = false
    @State private var didAppendLocationToDetails = false
    @State private var voicePlacementMode: VoicePlacementMode = .command
    @State private var manualVoiceTarget: VoiceFieldTarget = .description
    @State private var pendingVoiceTarget: VoiceFieldTarget?
    @State private var lastProcessedUtterance: String = ""
    @State private var mlStatusMessage: String = "Ready"
    @State private var ocrTextCache: String = ""
    @State private var detectedCategory: String = ""
    @State private var detectedDuplicateMessage: String = ""
    @State private var detectedBarcode: String = ""

    let initialImage: UIImage?
    let initialTitle: String?
    let initialDetails: String?
    let initialAmount: String?
    let appendCurrentLocationToDetails: Bool

    private let geocoder = CLGeocoder()

    init(
        initialImage: UIImage? = nil,
        initialTitle: String? = nil,
        initialDetails: String? = nil,
        initialAmount: String? = nil,
        appendCurrentLocationToDetails: Bool = false
    ) {
        self.initialImage = initialImage
        self.initialTitle = initialTitle
        self.initialDetails = initialDetails
        self.initialAmount = initialAmount
        self.appendCurrentLocationToDetails = appendCurrentLocationToDetails
    }

    var body: some View {
        NavigationStack {
            Form {
                TemplateSection(
                    showTemplatePickerSheet: $showTemplatePickerSheet,
                    applyTemplate: applyTemplate
                )
                
                ExpenseDetailsSection(
                    title: $title,
                    details: $details,
                    amount: $amount,
                    paymentMethod: $paymentMethod,
                    showSaveAsTemplateInput: $showSaveAsTemplateInput,
                    templateNameInput: $templateNameInput,
                    templateCategoryInput: $templateCategoryInput
                )

                VoiceCaptureSection(
                    voiceManager: voiceManager,
                    voicePlacementMode: $voicePlacementMode,
                    manualVoiceTarget: $manualVoiceTarget,
                    pendingVoiceTarget: $pendingVoiceTarget
                )

                LocationSection(
                    locationText: $locationText,
                    latitude: $latitude,
                    longitude: $longitude,
                    resolvingLocation: $resolvingLocation,
                    requestLocation: requestLocation
                )

                ReceiptPhotoSection(
                    selectedImage: $selectedImage,
                    showImagePicker: $showImagePicker,
                    imageSource: $imageSource
                )

                MLKitAssistantSection(
                    mlStatusMessage: $mlStatusMessage,
                    detectedCategory: $detectedCategory,
                    detectedDuplicateMessage: $detectedDuplicateMessage,
                    detectedBarcode: $detectedBarcode,
                    runOCRAutofill: runOCRAutofill,
                    runEntityExtraction: runEntityExtraction,
                    runLanguageNormalization: runLanguageNormalization,
                    runBarcodeScan: runBarcodeScan,
                    runQualityCheck: runQualityCheck,
                    runCategorySuggestion: runCategorySuggestion,
                    runDuplicateDetection: runDuplicateDetection,
                    runVoiceOCRFusion: runVoiceOCRFusion
                )
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExpense()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: imageSource, image: $selectedImage)
            }
            .sheet(isPresented: $showTemplatePickerSheet) {
                TemplatePickerView(isPresented: $showTemplatePickerSheet, onSelectTemplate: applyTemplate)
            }
            .task {
                locationManager.requestPermissionAndLocation()
                voiceManager.requestPermissions()
            }
            .onReceive(locationManager.$lastLocation) { newLocation in
                guard let newLocation else { return }
                latitude = newLocation.latitude
                longitude = newLocation.longitude
                resolveLocation(latitude: newLocation.latitude, longitude: newLocation.longitude)
            }
            .onAppear {
                requestLocation()

                if !didApplyInitialImage {
                    selectedImage = initialImage
                    didApplyInitialImage = true
                }

                if !didApplyInitialSharePayload {
                    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        title = initialTitle ?? ""
                    }
                    if details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        details = initialDetails ?? ""
                    }
                    if amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        amount = initialAmount ?? ""
                    }
                    didApplyInitialSharePayload = true
                }
            }
            .onDisappear {
                voiceManager.stopListening()
            }
            .onReceive(voiceManager.$latestFinalUtterance) { utterance in
                let trimmed = utterance.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed != lastProcessedUtterance else { return }
                lastProcessedUtterance = trimmed
                handleVoiceUtterance(trimmed)
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Double(amount) != nil
    }

    private func requestLocation() {
        resolvingLocation = true
        locationManager.requestPermissionAndLocation()
        if let coordinate = locationManager.lastLocation {
            latitude = coordinate.latitude
            longitude = coordinate.longitude
            resolveLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                resolvingLocation = false
            }
        }
    }

    private func resolveLocation(latitude: Double, longitude: Double) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            DispatchQueue.main.async {
                resolvingLocation = false
                if let placemark = placemarks?.first {
                    let parts = [placemark.name, placemark.locality, placemark.administrativeArea].compactMap { $0 }
                    locationText = parts.isEmpty ? "Current location" : parts.joined(separator: ", ")
                } else {
                    locationText = String(format: "%.5f, %.5f", latitude, longitude)
                }

                appendLocationToDetailsIfNeeded()
            }
        }
    }

    private func appendLocationToDetailsIfNeeded() {
        guard appendCurrentLocationToDetails,
              !didAppendLocationToDetails,
              !locationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let cleaned = details.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty {
            details = "Location: \(locationText)"
        } else if !cleaned.localizedCaseInsensitiveContains("location:") {
            details = "\(cleaned)\nLocation: \(locationText)"
        }
        didAppendLocationToDetails = true
    }

    private func handleVoiceUtterance(_ utterance: String) {
        let normalized = utterance.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = normalized.lowercased()

        if voicePlacementMode == .manual {
            assignVoiceText(normalized, to: manualVoiceTarget)
            return
        }

        if let target = pendingVoiceTarget {
            assignVoiceText(normalized, to: target)
            pendingVoiceTarget = nil
            return
        }

        if lower == "title" {
            pendingVoiceTarget = .title
            voiceManager.statusMessage = "Next voice -> Title"
            return
        }
        if lower == "description" {
            pendingVoiceTarget = .description
            voiceManager.statusMessage = "Next voice -> Description"
            return
        }
        if lower == "amount" {
            pendingVoiceTarget = .amount
            voiceManager.statusMessage = "Next voice -> Amount"
            return
        }

        if lower.hasPrefix("title ") {
            let value = String(normalized.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
            assignVoiceText(value, to: .title)
            return
        }
        if lower.hasPrefix("description ") {
            let value = String(normalized.dropFirst(12)).trimmingCharacters(in: .whitespacesAndNewlines)
            assignVoiceText(value, to: .description)
            return
        }
        if lower.hasPrefix("amount ") {
            let value = String(normalized.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
            assignVoiceText(value, to: .amount)
            return
        }

        assignVoiceText(normalized, to: .description)
    }

    private func assignVoiceText(_ text: String, to target: VoiceFieldTarget) {
        switch target {
        case .title:
            title = text
            voiceManager.statusMessage = "Updated Title"
        case .description:
            details = text
            voiceManager.statusMessage = "Updated Description"
        case .amount:
            if let parsed = extractFirstAmount(from: text) {
                amount = parsed
                voiceManager.statusMessage = "Updated Amount"
            } else {
                voiceManager.statusMessage = "No numeric amount found"
            }
        }
    }

    private func extractFirstAmount(from text: String) -> String? {
        let pattern = "[0-9]+(?:[.,][0-9]+)?"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return nil
        }

        let raw = String(text[range]).replacingOccurrences(of: ",", with: "")
        return Double(raw) != nil ? raw : nil
    }

    private func runOCRAutofill() {
        guard let selectedImage else {
            mlStatusMessage = "Attach a receipt image first"
            return
        }

        let assistant = MLKitExpenseAssistant.shared
        let payload = assistant.recognizeReceiptText(from: selectedImage)
        let entities = assistant.extractEntities(from: payload.text)
        ocrTextCache = payload.text

        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let merchant = entities.merchant,
           !merchant.isEmpty {
            title = merchant
        }

        if details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !payload.text.isEmpty {
            details = payload.text
        }

        if amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let amt = entities.amount {
            amount = String(format: "%.2f", amt)
        }

        mlStatusMessage = payload.text.isEmpty ? "OCR returned empty text" : "OCR auto-fill completed"
    }

    private func runEntityExtraction() {
        let source = ocrTextCache.isEmpty ? details : ocrTextCache
        let entities = MLKitExpenseAssistant.shared.extractEntities(from: source)

        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let merchant = entities.merchant,
           !merchant.isEmpty {
            title = merchant
        }

        if amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let amt = entities.amount {
            amount = String(format: "%.2f", amt)
        }

        mlStatusMessage = "Extraction complete"
    }

    private func runLanguageNormalization() {
        let normalized = MLKitExpenseAssistant.shared.normalizeLanguage(details)
        details = normalized
        mlStatusMessage = "Language normalization complete"
    }

    private func runBarcodeScan() {
        guard let selectedImage else {
            mlStatusMessage = "Attach a receipt image first"
            return
        }
        let barcodes = MLKitExpenseAssistant.shared.scanBarcodes(from: selectedImage)
        detectedBarcode = barcodes.first ?? ""
        mlStatusMessage = barcodes.isEmpty ? "No barcode detected" : "Barcode detected"
    }

    private func runQualityCheck() {
        guard let selectedImage else {
            mlStatusMessage = "Attach a receipt image first"
            return
        }

        let report = MLKitExpenseAssistant.shared.evaluateQuality(of: selectedImage)
        mlStatusMessage = report.suggestion
    }

    private func runCategorySuggestion() {
        let combined = [title, details].joined(separator: " ")
        detectedCategory = MLKitExpenseAssistant.shared.suggestCategory(from: combined)
        mlStatusMessage = "Category suggestion complete"
    }

    private func runDuplicateDetection() {
        let amountValue = Double(amount)
        let duplicate = MLKitExpenseAssistant.shared.detectDuplicate(
            title: title,
            amount: amountValue,
            details: details,
            in: store.expenses
        )

        if let duplicate {
            detectedDuplicateMessage = "Possible duplicate: \(duplicate.expense.title) (score \(String(format: "%.2f", duplicate.score)))"
        } else {
            detectedDuplicateMessage = "No duplicates detected"
        }
        mlStatusMessage = "Duplicate check complete"
    }

    private func runVoiceOCRFusion() {
        let entities = MLKitExpenseAssistant.shared.extractEntities(from: ocrTextCache.isEmpty ? details : ocrTextCache)
        let fusion = MLKitExpenseAssistant.shared.fuse(
            voiceTitle: title,
            voiceDetails: details,
            voiceAmountText: amount,
            ocrText: ocrTextCache,
            entities: entities
        )

        if let t = fusion.title, !t.isEmpty { title = t }
        if let d = fusion.details, !d.isEmpty { details = d }
        if let a = fusion.amount { amount = String(format: "%.2f", a) }
        mlStatusMessage = "Voice + OCR fusion complete"
    }

    private func saveExpense() {
        guard let amountValue = Double(amount) else { return }

        store.addExpense(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amountValue,
            paymentMethod: paymentMethod,
            image: selectedImage,
            locationName: locationText.isEmpty ? nil : locationText,
            latitude: latitude,
            longitude: longitude
        )
        
        if showSaveAsTemplateInput && !templateNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let template = ExpenseTemplate(
                id: UUID(),
                name: templateNameInput.trimmingCharacters(in: .whitespacesAndNewlines),
                category: templateCategoryInput.isEmpty ? "General" : templateCategoryInput,
                defaultAmount: amountValue,
                defaultPaymentMethod: paymentMethod,
                defaultLocationName: locationText.isEmpty ? nil : locationText
            )
            store.addTemplate(template)
        }
        
        dismiss()
    }
    
    private func applyTemplate(_ template: ExpenseTemplate) {
        store.markTemplateUsed(template)
        title = ""
        details = ""
        amount = template.defaultAmount.map { String(format: "%.2f", $0) } ?? ""
        paymentMethod = template.defaultPaymentMethod
        locationText = template.defaultLocationName ?? ""
        templateNameInput = template.name
        templateCategoryInput = template.category
        showTemplatePickerSheet = false
    }
}
