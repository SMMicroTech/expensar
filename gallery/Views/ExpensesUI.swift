import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: ExpensesStore
    @EnvironmentObject private var syncSettings: SyncSettingsStore
    @State private var selectedRange: DashboardRange = .month

    private var currencyCode: String {
        syncSettings.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroCard
                    summaryGrid
                    breakdownCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
        }
    }

    private var heroCard: some View {
        let total = store.total(for: selectedRange.component)

        return VStack(alignment: .leading, spacing: 14) {
            Text("Spending Overview")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(total.formatted(.currency(code: currencyCode)))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Picker("Range", selection: $selectedRange) {
                ForEach(DashboardRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(
            LinearGradient(colors: [Color.indigo, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(0.95)
        )
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
    }

    private var summaryGrid: some View {
        let today = store.total(for: .day)
        let week = store.total(for: .weekOfYear)
        let month = store.total(for: .month)

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            MetricCard(title: "Today", amount: today, systemImage: "sun.max.fill", tint: .orange, currencyCode: currencyCode)
            MetricCard(title: "This Week", amount: week, systemImage: "calendar.badge.clock", tint: .green, currencyCode: currencyCode)
            MetricCard(title: "This Month", amount: month, systemImage: "calendar", tint: .blue, currencyCode: currencyCode)
            MetricCard(title: "Records", amount: Double(store.expenses.count), systemImage: "doc.text.fill", tint: .purple, isCount: true)
        }
    }

    private var breakdownCard: some View {
        let entries = store.groupedTotals(by: selectedRange.component)
        let maxAmount = entries.map(\.amount).max() ?? 1

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Breakdown")
                    .font(.headline)
                Spacer()
                Text(selectedRange.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if entries.isEmpty {
                EmptyStateView(
                    title: "No expenses yet",
                    subtitle: "Add your first expense to see a breakdown.",
                    systemImage: "tray"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(entries, id: \.date) { item in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(label(for: item.date))
                                    .font(.subheadline.weight(.semibold))
                                Text(item.amount.formatted(.currency(code: currencyCode)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 12)
                            GeometryReader { geometry in
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(LinearGradient(colors: [.pink, .orange], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(12, geometry.size.width * CGFloat(item.amount / maxAmount)), height: 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 10)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    private func label(for date: Date) -> String {
        let formatter = DateFormatter()
        switch selectedRange {
        case .day:
            formatter.dateFormat = "EEE, d MMM"
        case .week:
            formatter.dateFormat = "d MMM"
        case .month:
            formatter.dateFormat = "MMM yyyy"
        case .year:
            formatter.dateFormat = "yyyy"
        }
        return formatter.string(from: date)
    }
}

struct ExpensesListView: View {
    @EnvironmentObject private var store: ExpensesStore
    @State private var showAddExpense = false
    @State private var selectedExpense: Expense?
    @State private var mapPreviewExpense: Expense?

    var body: some View {
        NavigationStack {
            Group {
                if store.expenses.isEmpty {
                    EmptyStateView(
                        title: "No expenses yet",
                        subtitle: "Add receipts, location, and payment details to start tracking.",
                        systemImage: "tray.full"
                    )
                } else {
                    List {
                        ForEach(groupedExpenses.keys.sorted(by: >), id: \.self) { date in
                            Section(dateFormatter.string(from: date)) {
                                ForEach(groupedExpenses[date] ?? []) { expense in
                            expenseRow(for: expense)
                        }
                                .onDelete(perform: deleteItems)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Expenses")
            .sheet(isPresented: $showAddExpense) {
                AddExpenseView()
                    .environmentObject(store)
            }
            .sheet(item: $selectedExpense) { expense in
                ExpenseDetailsView(expense: expense, image: store.image(for: expense.photoFilename))
            }
            .sheet(item: $mapPreviewExpense) { expense in
                ExpenseMapView(expense: expense)
            }
            .overlay(addExpenseButton, alignment: .bottomTrailing)
        }
    }

    @ViewBuilder
    private var addExpenseButton: some View {
        Button(action: {
            showAddExpense = true
        }) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(.blue)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 16)
    }

    private var groupedExpenses: [Date: [Expense]] {
        Dictionary(grouping: store.expenses) { Calendar.current.startOfDay(for: $0.date) }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }

    private func deleteItems(at offsets: IndexSet) {
        let groupedDates = groupedExpenses.keys.sorted(by: >)
        var flatList: [Expense] = []
        for date in groupedDates {
            flatList.append(contentsOf: groupedExpenses[date] ?? [])
        }
        let items = offsets.map { flatList[$0] }
        let indexes = IndexSet(items.compactMap { expense in store.expenses.firstIndex(where: { $0.id == expense.id }) })
        store.delete(at: indexes)
    }

    private func expenseRow(for expense: Expense) -> some View {
        Button(action: {
            selectedExpense = expense
        }) {
            ExpenseRowView(expense: expense, image: store.image(for: expense.photoFilename))
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .contextMenu {
            if expense.coordinate != nil {
                Button(action: {
                    mapPreviewExpense = expense
                }) {
                    Label("Open Map", systemImage: "map.fill")
                }
            } else {
                Text("No location available")
            }
        }
        .onLongPressGesture(minimumDuration: 0.45) {
            if expense.coordinate != nil {
                mapPreviewExpense = expense
            }
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            Text(title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(22)
        .shadow(color: Color.black.opacity(0.05), radius: 14, y: 8)
        .padding()
    }
}
