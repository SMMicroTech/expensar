import SwiftUI
import MapKit

struct ExpenseDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var syncSettings: SyncSettingsStore
    let expense: Expense
    let image: UIImage?
    @State private var isShowingFullscreenImage = false

    private var currencyCode: String {
        syncSettings.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let image {
                        Button(action: {
                            isShowingFullscreenImage = true
                        }) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $isShowingFullscreenImage) {
                            FullScreenImageView(image: image)
                        }
                    }

                    Group {
                        detailRow(title: "Title", value: expense.title)
                        detailRow(title: "Description", value: expense.details)
                        detailRow(title: "Amount", value: expense.formattedAmount(currencyCode: currencyCode))
                        detailRow(title: "Payment", value: expense.paymentMethod.rawValue)
                        detailRow(title: "Date", value: dateText)
                        if let locationName = expense.locationName {
                            detailRow(title: "Location", value: locationName)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Expense Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: expense.date)
    }

    @ViewBuilder
    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ExpenseMapView: View {
    let expense: Expense
    @State private var region: MKCoordinateRegion

    init(expense: Expense) {
        self.expense = expense
        if let coordinate = expense.coordinate {
            _region = State(initialValue: MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            ))
        } else {
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
            ))
        }
    }

    var body: some View {
        NavigationStack {
            Map(coordinateRegion: $region, annotationItems: annotationItem) { item in
                MapMarker(coordinate: item.coordinate, tint: .red)
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(expense.locationName ?? "Expense Location")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var annotationItem: [ExpenseLocation] {
        if let coordinate = expense.coordinate {
            return [ExpenseLocation(coordinate: coordinate)]
        }
        return []
    }
}

private struct ExpenseLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

extension Expense {
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
struct FullScreenImageView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage

    var body: some View {
        NavigationStack {
            ZoomableImageView(image: image)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Receipt Image")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
        }
    }
}

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = scrollView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.tag = 100
        scrollView.addSubview(imageView)

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        if let imageView = uiView.viewWithTag(100) as? UIImageView {
            imageView.image = image
        }
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        let parent: ZoomableImageView

        init(_ parent: ZoomableImageView) {
            self.parent = parent
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            scrollView.viewWithTag(100)
        }
    }
}
