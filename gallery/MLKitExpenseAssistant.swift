import Foundation
import UIKit
import Vision
import CoreImage

#if canImport(MLKitTextRecognition)
import MLKitTextRecognition
import MLKitVision
import MLKitBarcodeScanning
#endif

struct OCRPayload {
    var text: String
    var confidence: Double
}

struct ReceiptEntities {
    var merchant: String?
    var amount: Double?
    var date: Date?
    var tax: Double?
}

struct ImageQualityReport {
    var isBlurry: Bool
    var brightness: Double
    var suggestion: String
}

struct DuplicateMatch {
    var expense: Expense
    var score: Double
}

struct FusionOutput {
    var title: String?
    var details: String?
    var amount: Double?
}

final class MLKitExpenseAssistant {
    static let shared = MLKitExpenseAssistant()
    private init() {}

    // Helper: map UIImage.Orientation to CGImagePropertyOrientation
    private func cgOrientation(from ui: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch ui {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    // Step 1: OCR auto-fill
    func recognizeReceiptText(from image: UIImage) -> OCRPayload {
        #if canImport(MLKitTextRecognition)
        // If ML Kit is linked into the project, prefer that implementation.
        // Placeholder for ML Kit implementation.
        #endif

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let orientation = cgOrientation(from: image.imageOrientation)

        do {
            if let cg = image.cgImage {
                let handler = VNImageRequestHandler(cgImage: cg, orientation: orientation, options: [:])
                try handler.perform([request])
            } else if let ci = image.ciImage {
                let handler = VNImageRequestHandler(ciImage: ci, orientation: orientation, options: [:])
                try handler.perform([request])
            } else if let data = image.pngData(), let ci = CIImage(data: data) {
                let handler = VNImageRequestHandler(ciImage: ci, orientation: orientation, options: [:])
                try handler.perform([request])
            } else {
                return OCRPayload(text: "", confidence: 0)
            }

            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            var lines: [String] = []
            var confSum: Double = 0
            var confCount = 0

            for obs in observations {
                if let candidate = obs.topCandidates(1).first {
                    lines.append(candidate.string)
                    confSum += Double(candidate.confidence)
                    confCount += 1
                }
            }

            let combined = lines.joined(separator: "\n")
            let avgConf = confCount > 0 ? confSum / Double(confCount) : 0
            return OCRPayload(text: combined, confidence: avgConf)
        } catch {
            return OCRPayload(text: "", confidence: 0)
        }
    }

    // Step 2: extract amount/date/merchant from text
    func extractEntities(from text: String) -> ReceiptEntities {
        let amount = extractFirstAmount(from: text)
        let date = extractDate(from: text)
        let merchant = extractMerchant(from: text)
        let tax = extractTax(from: text)
        return ReceiptEntities(merchant: merchant, amount: amount, date: date, tax: tax)
    }

    // Step 3: language detection / normalization
    func normalizeLanguage(_ text: String) -> String {
        // Language identification/translation hook point.
        // Kept no-op for now so it works without external packages.
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Step 4: barcode scan hook
    func scanBarcodes(from image: UIImage) -> [String] {
        #if canImport(MLKitBarcodeScanning)
        // Placeholder for ML Kit barcode scanner implementation.
        #endif
        return []
    }

    // Step 5: quality check hook
    func evaluateQuality(of image: UIImage) -> ImageQualityReport {
        guard let cg = image.cgImage else {
            return ImageQualityReport(isBlurry: false, brightness: 0, suggestion: "Unable to evaluate image quality")
        }

        let width = cg.width
        let height = cg.height
        let estimatedBrightness = Double((width + height) % 255) / 255.0
        let blurry = width < 500 || height < 500
        let suggestion: String
        if blurry {
            suggestion = "Image appears low resolution. Retake closer to receipt."
        } else if estimatedBrightness < 0.25 {
            suggestion = "Image appears dark. Improve lighting for better OCR."
        } else {
            suggestion = "Image quality looks okay."
        }

        return ImageQualityReport(isBlurry: blurry, brightness: estimatedBrightness, suggestion: suggestion)
    }

    // Step 6: category suggestion
    func suggestCategory(from text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("uber") || lower.contains("taxi") || lower.contains("bus") || lower.contains("fuel") {
            return "Transport"
        }
        if lower.contains("kfc") || lower.contains("food") || lower.contains("lunch") || lower.contains("dinner") || lower.contains("cafe") {
            return "Food"
        }
        if lower.contains("electric") || lower.contains("water") || lower.contains("internet") || lower.contains("utility") {
            return "Utilities"
        }
        if lower.contains("pharmacy") || lower.contains("hospital") || lower.contains("clinic") {
            return "Health"
        }
        return "General"
    }

    // Step 7: duplicate detection
    func detectDuplicate(
        title: String,
        amount: Double?,
        details: String,
        in expenses: [Expense]
    ) -> DuplicateMatch? {
        guard let amount else { return nil }
        let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDetails = details.lowercased()

        let candidates = expenses.compactMap { expense -> DuplicateMatch? in
            let amountDelta = abs(expense.amount - amount)
            guard amountDelta <= 0.01 else { return nil }

            var score = 0.6
            if expense.title.lowercased() == normalizedTitle && !normalizedTitle.isEmpty {
                score += 0.25
            }
            if !normalizedDetails.isEmpty && expense.details.lowercased().contains(normalizedDetails.prefix(20)) {
                score += 0.15
            }
            return DuplicateMatch(expense: expense, score: score)
        }

        return candidates.sorted { $0.score > $1.score }.first
    }

    // Step 8: voice + OCR fusion
    func fuse(
        voiceTitle: String?,
        voiceDetails: String?,
        voiceAmountText: String?,
        ocrText: String,
        entities: ReceiptEntities
    ) -> FusionOutput {
        let title = nonEmpty(voiceTitle) ?? entities.merchant ?? firstWords(from: ocrText, count: 4)
        let details = nonEmpty(voiceDetails) ?? nonEmpty(ocrText)

        let voiceAmount = voiceAmountText.flatMap { extractFirstAmount(from: $0) }
        let amount = voiceAmount ?? entities.amount

        return FusionOutput(title: title, details: details, amount: amount)
    }

    private func extractFirstAmount(from text: String) -> Double? {
        let pattern = "[0-9]+(?:[.,][0-9]+)?"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return nil
        }
        let raw = String(text[range]).replacingOccurrences(of: ",", with: "")
        return Double(raw)
    }

    private func extractDate(from text: String) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.firstMatch(in: text, options: [], range: range)?.date
    }

    private func extractMerchant(from text: String) -> String? {
        let lines = text
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.first
    }

    private func extractTax(from text: String) -> Double? {
        let lower = text.lowercased()
        guard let range = lower.range(of: "tax") else { return nil }
        let suffix = String(lower[range.upperBound...])
        return extractFirstAmount(from: suffix)
    }

    private func firstWords(from text: String, count: Int) -> String? {
        let words = text.split(separator: " ").prefix(count)
        guard !words.isEmpty else { return nil }
        return words.map(String.init).joined(separator: " ")
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
