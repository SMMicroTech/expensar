import SwiftUI
import CoreLocation

// MARK: - Template Section
struct TemplateSection: View {
    @EnvironmentObject private var store: ExpensesStore
    @Binding var showTemplatePickerSheet: Bool
    let applyTemplate: (ExpenseTemplate) -> Void

    var body: some View {
        Section("Template") {
            Button {
                showTemplatePickerSheet = true
            } label: {
                HStack {
                    Label("Choose Template", systemImage: "bookmark.fill")
                        .foregroundColor(.accentColor)
                    Spacer()
                    if store.templates.count > 0 {
                        Text("\(store.templates.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            let frequent = store.frequentTemplates(limit: 6)
            if !frequent.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(frequent) { template in
                            Button {
                                applyTemplate(template)
                            } label: {
                                HStack(spacing: 6) {
                                    Text(template.name)
                                        .lineLimit(1)
                                    Text("\(store.usageCount(for: template))")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                                }
                                .font(.subheadline)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

// MARK: - Expense Details Section
struct ExpenseDetailsSection: View {
    @Binding var title: String
    @Binding var details: String
    @Binding var amount: String
    @Binding var paymentMethod: Expense.PaymentMethod
    @Binding var showSaveAsTemplateInput: Bool
    @Binding var templateNameInput: String
    @Binding var templateCategoryInput: String

    var body: some View {
        Section("Expense Details") {
            TextField("Title", text: $title)
            TextField("Description", text: $details, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
            TextField("Amount Spent", text: $amount)
                .keyboardType(.decimalPad)
            Picker("Payment Method", selection: $paymentMethod) {
                ForEach(Expense.PaymentMethod.allCases) { method in
                    Text(method.rawValue).tag(method)
                }
            }
            
            Toggle("Save as Template", isOn: $showSaveAsTemplateInput)
            if showSaveAsTemplateInput {
                TextField("Template Name", text: $templateNameInput)
                TextField("Category (optional)", text: $templateCategoryInput)
            }
        }
    }
}

// MARK: - Voice Capture Section
struct VoiceCaptureSection: View {
    @ObservedObject var voiceManager: VoiceCaptureManager
    @Binding var voicePlacementMode: VoicePlacementMode
    @Binding var manualVoiceTarget: VoiceFieldTarget
    @Binding var pendingVoiceTarget: VoiceFieldTarget?

    var body: some View {
        Section("Voice Capture (MLKit)") {
            Picker("Placement", selection: $voicePlacementMode) {
                ForEach(VoicePlacementMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if voicePlacementMode == .manual {
                Picker("Target", selection: $manualVoiceTarget) {
                    ForEach(VoiceFieldTarget.allCases) { target in
                        Text(target.rawValue).tag(target)
                    }
                }
            } else {
                Text("Say: title, description, or amount. Next sentence fills that field.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let pendingVoiceTarget {
                Text("Waiting for: \(pendingVoiceTarget.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Button {
                voiceManager.toggleListening()
            } label: {
                Label(
                    voiceManager.isListening ? "Stop Listening" : "Start Voice Capture",
                    systemImage: voiceManager.isListening ? "stop.circle.fill" : "mic.fill"
                )
            }

            Text(voiceManager.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Location Section
struct LocationSection: View {
    @Binding var locationText: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var resolvingLocation: Bool
    let requestLocation: () -> Void

    var body: some View {
        Section("Location") {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "location.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(locationText.isEmpty ? "No location selected" : locationText)
                        .font(.subheadline)
                    if let latitude, let longitude {
                        Text(String(format: "%.5f, %.5f", latitude, longitude))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button {
                requestLocation()
            } label: {
                Label(resolvingLocation ? "Getting Location..." : "Use Current Location", systemImage: "location.circle.fill")
            }
            .disabled(resolvingLocation)
        }
    }
}

// MARK: - Receipt Photo Section
struct ReceiptPhotoSection: View {
    @Binding var selectedImage: UIImage?
    @Binding var showImagePicker: Bool
    @Binding var imageSource: UIImagePickerController.SourceType

    var body: some View {
        Section("Receipt Photo") {
            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            Menu {
                Button {
                    imageSource = .photoLibrary
                    showImagePicker = true
                } label: {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                }

                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        imageSource = .camera
                        showImagePicker = true
                    } label: {
                        Label("Camera", systemImage: "camera")
                    }
                }
            } label: {
                Label(selectedImage == nil ? "Attach Bill Photo" : "Change Photo", systemImage: "paperclip")
            }
        }
    }
}

// MARK: - ML Kit Assistant Buttons
struct MLKitButtonsView: View {
    let runOCRAutofill: () -> Void
    let runEntityExtraction: () -> Void
    let runLanguageNormalization: () -> Void
    let runBarcodeScan: () -> Void
    let runQualityCheck: () -> Void
    let runCategorySuggestion: () -> Void
    let runDuplicateDetection: () -> Void
    let runVoiceOCRFusion: () -> Void

    var body: some View {
        Button("1) OCR Auto Fill") { runOCRAutofill() }
        Button("2) Extract Amount/Date/Merchant") { runEntityExtraction() }
        Button("3) Normalize Language") { runLanguageNormalization() }
        Button("4) Scan Barcode") { runBarcodeScan() }
        Button("5) Receipt Quality Check") { runQualityCheck() }
        Button("6) Suggest Category") { runCategorySuggestion() }
        Button("7) Duplicate Detection") { runDuplicateDetection() }
        Button("8) Voice + OCR Fusion") { runVoiceOCRFusion() }
    }
}

// MARK: - ML Kit Results
struct MLKitResultsView: View {
    @Binding var detectedCategory: String
    @Binding var detectedDuplicateMessage: String
    @Binding var detectedBarcode: String
    @Binding var mlStatusMessage: String

    var body: some View {
        if !detectedCategory.isEmpty {
            Text("Category: \(detectedCategory)")
                .font(.caption)
        }
        if !detectedDuplicateMessage.isEmpty {
            Text(detectedDuplicateMessage)
                .font(.caption)
                .foregroundStyle(.orange)
        }
        if !detectedBarcode.isEmpty {
            Text("Barcode: \(detectedBarcode)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Text(mlStatusMessage)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

// MARK: - ML Kit Assistant Section
struct MLKitAssistantSection: View {
    @Binding var mlStatusMessage: String
    @Binding var detectedCategory: String
    @Binding var detectedDuplicateMessage: String
    @Binding var detectedBarcode: String
    let runOCRAutofill: () -> Void
    let runEntityExtraction: () -> Void
    let runLanguageNormalization: () -> Void
    let runBarcodeScan: () -> Void
    let runQualityCheck: () -> Void
    let runCategorySuggestion: () -> Void
    let runDuplicateDetection: () -> Void
    let runVoiceOCRFusion: () -> Void

    var body: some View {
        Section("ML Kit Assistant") {
            MLKitButtonsView(
                runOCRAutofill: runOCRAutofill,
                runEntityExtraction: runEntityExtraction,
                runLanguageNormalization: runLanguageNormalization,
                runBarcodeScan: runBarcodeScan,
                runQualityCheck: runQualityCheck,
                runCategorySuggestion: runCategorySuggestion,
                runDuplicateDetection: runDuplicateDetection,
                runVoiceOCRFusion: runVoiceOCRFusion
            )

            MLKitResultsView(
                detectedCategory: $detectedCategory,
                detectedDuplicateMessage: $detectedDuplicateMessage,
                detectedBarcode: $detectedBarcode,
                mlStatusMessage: $mlStatusMessage
            )
        }
    }
}
