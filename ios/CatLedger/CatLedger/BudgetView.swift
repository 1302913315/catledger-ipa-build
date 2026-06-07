import SwiftUI

struct BudgetView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var showingBudgetEditor = false
    @State private var editingBudget: LedgerBudget?
    @State private var showingAssetEditor = false
    @State private var editingAsset: AssetLiability?

    var body: some View {
        CatPage(title: "预算资产", subtitle: "让钱有去处，也有归宿") {
            budgetSummary

            SectionHeader("月度预算", actionTitle: "新增") {
                showingBudgetEditor = true
            }

            if store.budgets.isEmpty {
                EmptyStateView(title: "还没有预算", message: "给本月设置一个温柔的花钱边界。", symbolName: "target")
            } else {
                ForEach(store.budgets) { budget in
                    Button {
                        editingBudget = budget
                    } label: {
                        BudgetRow(budget: budget)
                    }
                    .buttonStyle(.plain)
                }
            }

            SectionHeader("资产负债", actionTitle: "新增") {
                showingAssetEditor = true
            }

            CatCard {
                HStack {
                    Label("净资产", systemImage: "heart.text.square.fill")
                        .foregroundStyle(Color.catInk)
                    Spacer()
                    Text(moneyText(store.netWorthCents))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.catRose)
                }
            }

            ForEach(store.assets) { item in
                Button {
                    editingAsset = item
                } label: {
                    AssetRow(item: item)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingBudgetEditor) {
            NavigationStack {
                BudgetEditorView()
            }
        }
        .sheet(item: $editingBudget) { budget in
            NavigationStack {
                BudgetEditorView(existing: budget)
            }
        }
        .sheet(isPresented: $showingAssetEditor) {
            NavigationStack {
                AssetEditorView()
            }
        }
        .sheet(item: $editingAsset) { item in
            NavigationStack {
                AssetEditorView(existing: item)
            }
        }
    }

    private var budgetSummary: some View {
        CatCard {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("本月预算")
                        .font(.headline)
                        .foregroundStyle(Color.catInk)
                    Text(store.currentBudgetCents == 0 ? "预算暂未开启" : "\(moneyText(store.monthlyExpenseCents)) / \(moneyText(store.currentBudgetCents))")
                        .font(.subheadline)
                        .foregroundStyle(Color.catSubtext)
                }
                Spacer()
                Text("\(Int(store.currentBudgetProgress * 100))%")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(store.currentBudgetProgress >= 1 ? Color.catRose : Color.catMint)
            }
            ProgressView(value: min(1, store.currentBudgetProgress))
                .tint(store.currentBudgetProgress >= 1 ? .catRose : .catMint)
        }
    }
}

private struct BudgetRow: View {
    @EnvironmentObject private var store: LedgerStore
    var budget: LedgerBudget

    var body: some View {
        CatCard {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.catInk)
                    Text("\(budget.monthKey) · 提醒 \(Int(budget.warningRatio * 100))%")
                        .font(.caption)
                        .foregroundStyle(Color.catSubtext)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(moneyText(budget.amountCents))
                        .font(.headline)
                        .foregroundStyle(Color.catRose)
                    PillLabel(text: budget.isEnabled ? "已开启" : "已关闭", symbolName: budget.isEnabled ? "checkmark.circle.fill" : "pause.circle", tint: budget.isEnabled ? .catMint : .catSubtext)
                }
            }
        }
    }

    private var title: String {
        if let category = store.category(for: budget.categoryID) {
            return "\(category.name)预算"
        }
        return "总预算"
    }
}

private struct AssetRow: View {
    var item: AssetLiability

    var body: some View {
        CatCard {
            HStack {
                Image(systemName: item.kind == .asset ? "plus.circle.fill" : "minus.circle.fill")
                    .foregroundStyle(Color(hex: item.colorHex))
                    .frame(width: 34, height: 34)
                    .background(Color(hex: item.colorHex).opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundStyle(Color.catInk)
                    Text(item.note.isEmpty ? item.kind.rawValue : item.note)
                        .font(.caption)
                        .foregroundStyle(Color.catSubtext)
                        .lineLimit(1)
                }
                Spacer()
                Text(moneyText(item.balanceCents))
                    .font(.headline)
                    .foregroundStyle(item.kind == .asset ? Color.catMint : Color.catRose)
            }
        }
    }
}

private struct BudgetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LedgerStore

    var existing: LedgerBudget?
    @State private var amount: String
    @State private var monthKey: String
    @State private var categoryID: UUID?
    @State private var warningRatio: Double
    @State private var isEnabled: Bool
    @State private var alertMessage: String?
    @State private var showingDeleteAlert = false

    init(existing: LedgerBudget? = nil) {
        self.existing = existing
        _amount = State(initialValue: existing.map { amountText($0.amountCents) } ?? "5000")
        _monthKey = State(initialValue: existing?.monthKey ?? Date().monthKey)
        _categoryID = State(initialValue: existing?.categoryID)
        _warningRatio = State(initialValue: existing?.warningRatio ?? 0.85)
        _isEnabled = State(initialValue: existing?.isEnabled ?? true)
    }

    var body: some View {
        Form {
            Section("预算") {
                TextField("金额", text: $amount)
                    .keyboardType(.decimalPad)
                TextField("月份 yyyy-MM", text: $monthKey)
                Picker("范围", selection: $categoryID) {
                    Text("总预算")
                        .tag(Optional<UUID>.none)
                    ForEach(store.categories.filter { $0.kind == .expense }) { category in
                        Text(category.name)
                            .tag(Optional(category.id))
                    }
                }
                Toggle("开启预算", isOn: $isEnabled)
            }

            Section("提醒") {
                Slider(value: $warningRatio, in: 0.5...1, step: 0.05)
                Text("达到 \(Int(warningRatio * 100))% 时标记为接近超支")
                    .font(.footnote)
                    .foregroundStyle(Color.catSubtext)
            }

            if existing != nil {
                Section {
                    Button("删除预算", role: .destructive) {
                        showingDeleteAlert = true
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.catBackground.ignoresSafeArea())
        .navigationTitle(existing == nil ? "新增预算" : "编辑预算")
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
        .alert("删除预算？", isPresented: $showingDeleteAlert) {
            Button("删除", role: .destructive) {
                if let id = existing?.id {
                    store.deleteBudget(id: id)
                }
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
    }

    private func save() {
        guard let amountCents = cents(from: amount) else {
            alertMessage = "请输入有效金额。"
            return
        }
        let budget = LedgerBudget(
            id: existing?.id ?? UUID(),
            monthKey: monthKey,
            categoryID: categoryID,
            amountCents: amountCents,
            warningRatio: warningRatio,
            isEnabled: isEnabled
        )
        store.upsertBudget(budget)
        dismiss()
    }
}

private struct AssetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LedgerStore

    var existing: AssetLiability?
    @State private var name: String
    @State private var kind: AssetLiabilityKind
    @State private var balance: String
    @State private var colorHex: String
    @State private var note: String
    @State private var alertMessage: String?
    @State private var showingDeleteAlert = false

    init(existing: AssetLiability? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _kind = State(initialValue: existing?.kind ?? .asset)
        _balance = State(initialValue: existing.map { amountText($0.balanceCents) } ?? "")
        _colorHex = State(initialValue: existing?.colorHex ?? "#F178A6")
        _note = State(initialValue: existing?.note ?? "")
    }

    var body: some View {
        Form {
            Section("资产负债") {
                TextField("名称，例如 应急金", text: $name)
                Picker("类型", selection: $kind) {
                    ForEach(AssetLiabilityKind.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                TextField("余额", text: $balance)
                    .keyboardType(.decimalPad)
                TextField("备注", text: $note, axis: .vertical)
                    .lineLimit(2...4)
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

            if existing != nil {
                Section {
                    Button("删除资产负债", role: .destructive) {
                        showingDeleteAlert = true
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.catBackground.ignoresSafeArea())
        .navigationTitle(existing == nil ? "新增资产" : "编辑资产")
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
        .alert("删除这项？", isPresented: $showingDeleteAlert) {
            Button("删除", role: .destructive) {
                if let id = existing?.id {
                    store.deleteAsset(id: id)
                }
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
    }

    private func save() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "请输入名称。"
            return
        }
        guard let balanceCents = cents(from: balance) ?? (balance == "0" ? 0 : nil) else {
            alertMessage = "请输入有效余额。"
            return
        }
        let item = AssetLiability(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            balanceCents: balanceCents,
            colorHex: colorHex,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        if existing == nil {
            store.addAsset(item)
        } else {
            store.updateAsset(item)
        }
        dismiss()
    }
}
