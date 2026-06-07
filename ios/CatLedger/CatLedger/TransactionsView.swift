import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var searchText = ""
    @State private var selectedKind: TransactionKind?
    @State private var showingEditor = false
    @State private var editingTransaction: LedgerTransaction?

    var body: some View {
        CatPage(title: "账单明细", subtitle: "每一笔都清清楚楚") {
            filterBar

            if filteredTransactions.isEmpty {
                EmptyStateView(
                    title: "没有匹配账单",
                    message: "换个关键词，或者添加一笔新的记录。",
                    symbolName: "magnifyingglass"
                )
            } else {
                ForEach(store.groupedTransactions(filteredTransactions), id: \.0) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group.0)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.catSubtext)
                            .padding(.horizontal, 4)

                        ForEach(group.1) { item in
                            Button {
                                editingTransaction = item
                            } label: {
                                TransactionRow(transaction: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "搜索备注、标签、分类")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditor = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                TransactionEditorView()
            }
        }
        .sheet(item: $editingTransaction) { item in
            NavigationStack {
                TransactionDetailEditor(transaction: item)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    selectedKind = nil
                } label: {
                    PillLabel(text: "全部", symbolName: "tray.full.fill", tint: selectedKind == nil ? .catRose : .catSubtext)
                }
                .buttonStyle(.plain)

                ForEach(TransactionKind.allCases) { kind in
                    Button {
                        selectedKind = kind
                    } label: {
                        PillLabel(text: kind.rawValue, symbolName: kind.symbolName, tint: selectedKind == kind ? .catRose : .catSubtext)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var filteredTransactions: [LedgerTransaction] {
        store.transactions.filter { item in
            if let selectedKind, item.kind != selectedKind {
                return false
            }
            guard !searchText.isEmpty else {
                return true
            }
            let category = store.category(for: item.categoryID)?.name ?? ""
            let account = store.account(for: item.accountID)?.name ?? ""
            let haystack = "\(category) \(account) \(item.note) \(item.tags.joined(separator: " "))"
            return haystack.localizedCaseInsensitiveContains(searchText)
        }
    }
}

private struct TransactionDetailEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LedgerStore
    var transaction: LedgerTransaction
    @State private var showingDeleteAlert = false

    var body: some View {
        TransactionEditorView(existing: transaction)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("删除这笔", systemImage: "trash.fill")
                    }
                }
            }
            .alert("删除这笔账单？", isPresented: $showingDeleteAlert) {
                Button("删除", role: .destructive) {
                    store.deleteTransaction(id: transaction.id)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后会同步影响账户余额和统计。")
            }
    }
}
