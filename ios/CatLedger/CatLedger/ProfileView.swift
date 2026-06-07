import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var showingCategoryEditor = false
    @State private var editingCategory: LedgerCategory?
    @State private var showingAccountEditor = false
    @State private var editingAccount: LedgerAccount?

    var body: some View {
        CatPage(title: "我的", subtitle: "猫猫陪你认真记账") {
            profileCard

            SectionHeader("分类管理", actionTitle: "新增") {
                showingCategoryEditor = true
            }
            ForEach(store.categories) { category in
                Button {
                    editingCategory = category
                } label: {
                    CategoryRow(category: category)
                }
                .buttonStyle(.plain)
            }

            SectionHeader("账户管理", actionTitle: "新增") {
                showingAccountEditor = true
            }
            ForEach(store.accounts) { account in
                Button {
                    editingAccount = account
                } label: {
                    AccountRow(account: account)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingCategoryEditor) {
            NavigationStack {
                CategoryEditorView()
            }
        }
        .sheet(item: $editingCategory) { category in
            NavigationStack {
                CategoryEditorView(existing: category)
            }
        }
        .sheet(isPresented: $showingAccountEditor) {
            NavigationStack {
                AccountEditorView()
            }
        }
        .sheet(item: $editingAccount) { account in
            NavigationStack {
                AccountEditorView(existing: account)
            }
        }
    }

    private var profileCard: some View {
        CatCard {
            HStack(spacing: 14) {
                Image("CatAvatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .catRose.opacity(0.18), radius: 10, x: 0, y: 6)

                VStack(alignment: .leading, spacing: 6) {
                    Text("猫猫记账")
                        .font(.title2.bold())
                        .foregroundStyle(Color.catInk)
                    Text("本地离线保存 · 无账号 · 无云同步")
                        .font(.subheadline)
                        .foregroundStyle(Color.catSubtext)
                    HStack {
                        PillLabel(text: "\(store.transactions.count) 笔", symbolName: "list.bullet", tint: .catRose)
                        PillLabel(text: "\(store.accounts.count) 个账户", symbolName: "creditcard.fill", tint: .catMint)
                    }
                }
            }
        }
    }
}

private struct CategoryRow: View {
    var category: LedgerCategory

    var body: some View {
        CatCard {
            HStack {
                Image(systemName: category.symbolName)
                    .foregroundStyle(Color(hex: category.colorHex))
                    .frame(width: 34, height: 34)
                    .background(Color(hex: category.colorHex).opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.name)
                        .font(.headline)
                        .foregroundStyle(Color.catInk)
                    Text(category.kind.rawValue)
                        .font(.caption)
                        .foregroundStyle(Color.catSubtext)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(Color.catSubtext)
            }
        }
    }
}

private struct AccountRow: View {
    @EnvironmentObject private var store: LedgerStore
    var account: LedgerAccount

    var body: some View {
        CatCard {
            HStack {
                Image(systemName: account.kind == .credit ? "creditcard.fill" : "wallet.pass.fill")
                    .foregroundStyle(Color(hex: account.colorHex))
                    .frame(width: 34, height: 34)
                    .background(Color(hex: account.colorHex).opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.headline)
                        .foregroundStyle(Color.catInk)
                    Text(account.kind.rawValue)
                        .font(.caption)
                        .foregroundStyle(Color.catSubtext)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(moneyText(store.balance(for: account.id)))
                        .font(.headline)
                        .foregroundStyle(Color.catInk)
                    Text(account.includeInNetWorth ? "计入资产" : "不计入资产")
                        .font(.caption2)
                        .foregroundStyle(Color.catSubtext)
                }
            }
        }
    }
}

private struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LedgerStore

    var existing: LedgerCategory?
    @State private var name: String
    @State private var kind: TransactionKind
    @State private var symbolName: String
    @State private var colorHex: String
    @State private var alertMessage: String?
    @State private var showingDeleteAlert = false

    init(existing: LedgerCategory? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _kind = State(initialValue: existing?.kind ?? .expense)
        _symbolName = State(initialValue: existing?.symbolName ?? "heart.fill")
        _colorHex = State(initialValue: existing?.colorHex ?? "#F178A6")
    }

    var body: some View {
        Form {
            Section("分类") {
                TextField("名称", text: $name)
                Picker("类型", selection: $kind) {
                    ForEach([TransactionKind.expense, .income]) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                Picker("图标", selection: $symbolName) {
                    ForEach(symbols, id: \.self) { symbol in
                        Label(symbol, systemImage: symbol).tag(symbol)
                    }
                }
            }

            Section("颜色") {
                HStack {
                    ForEach(colors, id: \.self) { color in
                        Button {
                            colorHex = color
                        } label: {
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Circle()
                                        .stroke(colorHex == color ? Color.catInk : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if existing != nil {
                Section {
                    Button("删除分类", role: .destructive) {
                        showingDeleteAlert = true
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.catBackground.ignoresSafeArea())
        .navigationTitle(existing == nil ? "新增分类" : "编辑分类")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
            }
        }
        .alert("还差一点点", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .alert("删除分类？", isPresented: $showingDeleteAlert) {
            Button("删除", role: .destructive) {
                if let id = existing?.id {
                    store.deleteCategory(id: id)
                }
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
    }

    private let symbols = [
        "fork.knife", "tram.fill", "bag.fill", "house.fill", "gamecontroller.fill",
        "cross.case.fill", "book.fill", "banknote.fill", "briefcase.fill",
        "chart.line.uptrend.xyaxis", "gift.fill", "heart.fill"
    ]

    private let colors = ["#F178A6", "#FFD0BD", "#F2A65A", "#BDEEDB", "#7FC8F8", "#C783FF"]

    private func save() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "请输入分类名称。"
            return
        }
        let nextOrder = existing?.sortOrder ?? ((store.categories.map(\.sortOrder).max() ?? 0) + 1)
        let category = LedgerCategory(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            symbolName: symbolName,
            colorHex: colorHex,
            kind: kind,
            sortOrder: nextOrder
        )
        if existing == nil {
            store.addCategory(category)
        } else {
            store.updateCategory(category)
        }
        dismiss()
    }
}

private struct AccountEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LedgerStore

    var existing: LedgerAccount?
    @State private var name: String
    @State private var kind: AccountKind
    @State private var openingBalance: String
    @State private var colorHex: String
    @State private var includeInNetWorth: Bool
    @State private var alertMessage: String?
    @State private var showingDeleteAlert = false

    init(existing: LedgerAccount? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _kind = State(initialValue: existing?.kind ?? .wallet)
        _openingBalance = State(initialValue: existing.map { amountText($0.openingBalanceCents) } ?? "0")
        _colorHex = State(initialValue: existing?.colorHex ?? "#BDEEDB")
        _includeInNetWorth = State(initialValue: existing?.includeInNetWorth ?? true)
    }

    var body: some View {
        Form {
            Section("账户") {
                TextField("名称", text: $name)
                Picker("类型", selection: $kind) {
                    ForEach(AccountKind.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                TextField("初始余额", text: $openingBalance)
                    .keyboardType(.decimalPad)
                Toggle("计入净资产", isOn: $includeInNetWorth)
            }

            Section("颜色") {
                HStack {
                    ForEach(["#F178A6", "#FFD0BD", "#BDEEDB", "#7FC8F8", "#C783FF"], id: \.self) { color in
                        Button {
                            colorHex = color
                        } label: {
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Circle()
                                        .stroke(colorHex == color ? Color.catInk : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if existing != nil && store.accounts.count > 1 {
                Section {
                    Button("删除账户", role: .destructive) {
                        showingDeleteAlert = true
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.catBackground.ignoresSafeArea())
        .navigationTitle(existing == nil ? "新增账户" : "编辑账户")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
            }
        }
        .alert("还差一点点", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .alert("删除账户？", isPresented: $showingDeleteAlert) {
            Button("删除", role: .destructive) {
                if let id = existing?.id {
                    store.deleteAccount(id: id)
                }
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("关联账单会转移到其他账户。")
        }
    }

    private func save() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "请输入账户名称。"
            return
        }
        let balanceCents = cents(from: openingBalance) ?? 0
        let account = LedgerAccount(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            openingBalanceCents: balanceCents,
            colorHex: colorHex,
            includeInNetWorth: includeInNetWorth
        )
        if existing == nil {
            store.addAccount(account)
        } else {
            store.updateAccount(account)
        }
        dismiss()
    }
}
