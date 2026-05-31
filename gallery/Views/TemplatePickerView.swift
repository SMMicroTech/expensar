import SwiftUI

struct TemplatePickerView: View {
    @EnvironmentObject private var store: ExpensesStore
    @Binding var isPresented: Bool
    let onSelectTemplate: (ExpenseTemplate) -> Void

    var body: some View {
        NavigationView {
            if store.templates.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Templates Yet")
                        .font(.headline)
                    Text("Create a template by saving an expense with the 'Save as Template' option.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .navigationTitle("Choose Template")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            isPresented = false
                        }
                    }
                }
            } else {
                List {
                    ForEach(store.templates) { template in
                        Button {
                            onSelectTemplate(template)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                HStack(spacing: 12) {
                                    Label(template.category, systemImage: "tag.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if let amount = template.defaultAmount {
                                        Label(String(format: "LKR %.2f", amount), systemImage: "banknote")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                store.deleteTemplate(template)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .navigationTitle("Choose Template")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            isPresented = false
                        }
                    }
                }
            }
        }
    }
}
