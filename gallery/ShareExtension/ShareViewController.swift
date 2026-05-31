import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // Process input items
        if let context = extensionContext {
            handleContext(context)
        } else {
            complete()
        }
    }

    private func handleContext(_ context: NSExtensionContext) {
        guard let item = context.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            complete()
            return
        }

        // Find first image provider
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (item, error) in
                    guard let self = self else { return }
                    if let url = item as? URL, url.isFileURL {
                        self.saveAndOpen(url: url)
                    } else if let data = item as? Data {
                        self.saveAndOpen(data: data)
                    } else if let image = item as? UIImage, let d = image.jpegData(compressionQuality: 0.9) {
                        self.saveAndOpen(data: d)
                    } else {
                        self.complete()
                    }
                }
                return
            }
        }

        // Fallback: find first text provider
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier)
                || provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                let typeIdentifier = provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
                    ? UTType.plainText.identifier
                    : UTType.text.identifier

                provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] (item, error) in
                    guard let self = self else { return }

                    if let text = item as? String {
                        self.openHostApp(withText: text)
                    } else if let text = item as? NSString {
                        self.openHostApp(withText: text as String)
                    } else if let data = item as? Data,
                              let text = String(data: data, encoding: .utf8) {
                        self.openHostApp(withText: text)
                    } else if let url = item as? URL,
                              let text = try? String(contentsOf: url) {
                        self.openHostApp(withText: text)
                    } else {
                        self.complete()
                    }
                }
                return
            }
        }

        // No supported content found
        complete()
    }

    private func saveAndOpen(url: URL) {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.netdots.expensar") else {
            complete()
            return
        }
        let dest = container.appendingPathComponent("shared_\(UUID().uuidString).\(url.pathExtension)")
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            openHostApp(imageFileURL: dest, sharedText: nil, amount: nil, suggestedTitle: nil)
        } catch {
            openHostApp(imageFileURL: url, sharedText: nil, amount: nil, suggestedTitle: nil)
        }
    }

    private func saveAndOpen(data: Data) {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.netdots.expensar") else {
            complete()
            return
        }
        let dest = container.appendingPathComponent("shared_\(UUID().uuidString).jpg")
        do {
            try data.write(to: dest)
            openHostApp(imageFileURL: dest, sharedText: nil, amount: nil, suggestedTitle: nil)
        } catch {
            complete()
        }
    }

    private func openHostApp(withText text: String) {
        let normalized = normalizeText(text)
        let suggestedTitle = generateTitle(from: normalized)
        let parsedAmount = extractFirstAmount(from: normalized)
        openHostApp(imageFileURL: nil, sharedText: normalized, amount: parsedAmount, suggestedTitle: suggestedTitle)
    }

    private func openHostApp(
        imageFileURL: URL?,
        sharedText: String?,
        amount: String?,
        suggestedTitle: String?
    ) {
        // Build URL to open host app with parsed payload
        var components = URLComponents()
        components.scheme = "expensar"
        components.host = "open"
        var queryItems: [URLQueryItem] = []

        if let imageFileURL {
            queryItems.append(URLQueryItem(name: "imageFileURL", value: imageFileURL.absoluteString))
        }
        if let sharedText, !sharedText.isEmpty {
            queryItems.append(URLQueryItem(name: "sharedText", value: sharedText))
        }
        if let amount, !amount.isEmpty {
            queryItems.append(URLQueryItem(name: "sharedAmount", value: amount))
        }
        if let suggestedTitle, !suggestedTitle.isEmpty {
            queryItems.append(URLQueryItem(name: "sharedTitle", value: suggestedTitle))
        }

        components.queryItems = queryItems

        if let url = components.url {
            extensionContext?.open(url, completionHandler: { [weak self] success in
                DispatchQueue.main.async {
                    self?.complete()
                }
            })
        } else {
            complete()
        }
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func normalizeText(_ input: String) -> String {
        input
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractFirstAmount(from text: String) -> String? {
        let pattern = "[0-9]+(?:[,.][0-9]+)?"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return nil
        }

        let raw = String(text[range]).replacingOccurrences(of: ",", with: "")
        return Double(raw) != nil ? raw : nil
    }

    private func generateTitle(from description: String) -> String {
        let words = description
            .split { $0.isWhitespace }
            .prefix(4)
            .map(String.init)
        return words.isEmpty ? "Shared Expense" : words.joined(separator: " ")
    }
}
