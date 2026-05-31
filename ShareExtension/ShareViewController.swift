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

        // No image found
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
            openHostApp(with: dest)
        } catch {
            openHostApp(with: url)
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
            openHostApp(with: dest)
        } catch {
            complete()
        }
    }

    private func openHostApp(with fileURL: URL) {
        // Build URL to open host app with file path
        var components = URLComponents()
        components.scheme = "expensar"
        components.host = "open"
        let item = URLQueryItem(name: "imageFileURL", value: fileURL.absoluteString)
        components.queryItems = [item]
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
}
