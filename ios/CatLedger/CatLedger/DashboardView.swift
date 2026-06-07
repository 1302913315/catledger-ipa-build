import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var showingEditor = false

    var body: some View {
        CatPage(title: "猫猫记账", subtitle: "今天也要温柔地照顾钱包") {
            balanceCard

            HStack(spacing: 12) {
                MetricTile(
                    title: "本月收入",
                    value: moneyText(store.monthlyIncomeCents),
                    symbolName: "arrow.up.right",
                    tint: .catMint
                )
                MetricTile(
                    title: "本月支出",
                    value: moneyText(store.monthlyExpenseCents),
                    symbolName: "arrow.down.left",
                    tint: .catRose
                )
            }

            budgetProgress

            SectionHeader("最近明细", actionTitle: "记一笔") {
                showingEditor = true
            }

            if store.transactions.isEmpty {
                EmptyStateView(
                    title: "还没有账单",
                    message: "点一下右上角或下方按钮，记录第一笔可爱的账。",
                    symbolName: "sparkles"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(store.transactions.prefix(5)) { item in
                        TransactionRow(transaction: item)
                    }
                }
            }

            Button {
                showingEditor = true
            } label: {
                Label("快速记账", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(.borderedProminent)
            .tint(.catRose)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditor = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .accessibilityLabel("记一笔")
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                TransactionEditorView()
            }
        }
    }

    private var balanceCard: some View {
        CatCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("本月结余")
                        .font(.subheadline)
                        .foregroundStyle(Color.catSubtext)
                    Text(moneyText(store.monthBalanceCents))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.catInk)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("净资产 \(moneyText(store.netWorthCents))")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.catRose)
                }
                Spacer()
                Image("CatAvatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 82, height: 82)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white, lineWidth: 3)
                    )
            }
        }
    }

    private var budgetProgress: some View {
        CatCard {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("预算进度")
                        .font(.headline)
                        .foregroundStyle(Color.catInk)
                    Text(store.currentBudgetCents == 0 ? "还没有开启月预算" : "\(moneyText(store.monthlyExpenseCents)) / \(moneyText(store.currentBudgetCents))")
                        .font(.subheadline)
                        .foregroundStyle(Color.catSubtext)
                }
                Spacer()
                PillLabel(
                    text: "\(Int(store.currentBudgetProgress * 100))%",
                    symbolName: "target",
                    tint: store.currentBudgetProgress >= 1 ? .catRose : .catMint
                )
            }

            ProgressView(value: min(1, store.currentBudgetProgress))
                .tint(store.currentBudgetProgress >= 1 ? .catRose : .catMint)
        }
    }
}

struct TransactionRow: View {
    @EnvironmentObject private var store: LedgerStore
    var transaction: LedgerTransaction

    var body: some View {
        CatCard {
            HStack(spacing: 12) {
                Image(systemName: category?.symbolName ?? transaction.kind.symbolName)
                    .font(.title3)
                    .foregroundStyle(Color(hex: category?.colorHex ?? transaction.kind.tintHex))
                    .frame(width: 42, height: 42)
                    .background(Color(hex: category?.colorHex ?? transaction.kind.tintHex).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.kind == .transfer ? transferTitle : (category?.name ?? transaction.kind.rawValue))
                        .font(.headline)
                        .foregroundStyle(Color.catInk)
                    Text(rowSubtitle)
                        .font(.caption)
                        .foregroundStyle(Color.catSubtext)
                        .lineLimit(1)
                }

                Spacer()

                Text(displayAmount)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(amountColor)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
        }
    }

    private var category: LedgerCategory? {
        store.category(for: transaction.categoryID)
    }

    private var displayAmount: String {
        switch transaction.kind {
        case .expense: "-\(moneyText(transaction.amountCents))"
        case .income: "+\(moneyText(transaction.amountCents))"
        case .transfer: moneyText(transaction.amountCents)
        }
    }

    private var amountColor: Color {
        switch transaction.kind {
        case .expense: .catRose
        case .income: .catMint
        case .transfer: .catSubtext
        }
    }

    private var transferTitle: String {
        let from = store.account(for: transaction.accountID)?.name ?? "账户"
        let to = store.account(for: transaction.toAccountID)?.name ?? "账户"
        return "\(from) → \(to)"
    }

    private var rowSubtitle: String {
        let account = store.account(for: transaction.accountID)?.name ?? "未命名账户"
        let note = transaction.note.isEmpty ? "" : " · \(transaction.note)"
        let attachment = transaction.attachmentIDs.isEmpty ? "" : " · 附件"
        return "\(Date.shortDayFormatter.string(from: transaction.date)) · \(account)\(note)\(attachment)"
    }
}
