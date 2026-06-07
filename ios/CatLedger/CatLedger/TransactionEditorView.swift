import SwiftUI

struct TransactionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LedgerStore

    var existing: LedgerTransaction?

    @State private var kind: TransactionKind
    @State private var amount: String
    @State private var categoryID: UUID?
    @State private var accountID: UUID?
    @State private var toAccountID: UUID?
    @State private var date: Date
    @State private var note: String
    @State private var tagsText: String
    @State private var isRefund: Bool
    @State private var isReimbursed: Bool
    @State private var attachmentIDs: [UUID]
    @State private var alertMessage: String?

    init(existing: LedgerTransaction? = nil, ocrText: String = "", attachmentIDs: [UUID] = []) {
        self.existing = existing
        _kind = State(initialValue: existing?.kind ?? .expense)
        _amount = State(initialValue: existing.map { amountText($0.amountCents) } ?? extractLargestAmount(from: ocrText))
        _categoryID = State(initialValue: existing?.categoryID)
        _accountID = State(initialValue: existing?.accountID)
        _toAccountID = State(initialValue: existing?.toAccountID)
        _date = State(initialValue: existing?.date ?? Date())
        _note = State(initialValue: existing?.note ?? ocrText)
        _tagsText = State(initialValue: existing?.tags.joined(separator: " ") ?? "")
        _isRefund = State(initialValue: existing?.isRefund ?? false)
        _isReimbursed = State(initialValue: existing?.isReimbursed ?? false)
        _attachmentIDs = State(initialValue: existing?.attachmentIDs ?? attachmentIDs)
    }

    var body: some View {
        Form {
            Section {
                Picker("类型", selection: $kind) {
                    ForEach(TransactionKind.allCases) { item in
                        Label(item.rawValue, systemImage: item.symbolName)
                            .tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("金额与时间") {
                TextField("金额，例如 36.50", text: $amount)
                    .keyboardType(.decimalPad)
                DatePicker("日期", selection: $date, displayedComponents: [.date])
            }

            Section("分类与账户") {
                if kind != .transfer {
                    Picker("分类", selection: Binding(
                        get: { categoryID ?? filteredCategories.first?.id },
                        set: { categoryID = $0 }
                    )) {
                        ForEach(filteredCategories) { category in
                            Label(category.name, systemImage: category.symbolName)
                                .tag(Optional(category.id))
                        }
                    }
                }

                Picker(kind == .transfer ? "转出账户" : "账户", selection: Binding(
                    get: { accountID ?? store.accounts.first?.id },
                    set: { accountID = $0 }
                )) {
                    ForEach(store.accounts) { account in
                        Text(account.name)
                            .tag(Optional(account.id))
                    }
                }

                if kind == .transfer {
                    Picker("转入账户", selection: Binding(
                        get: { toAccountID ?? store.accounts.dropFirst().first?.id ?? store.accounts.first?.id },
                        set: { toAccountID = $0 }
                    )) {
                        ForEach(store.accounts) { account in
                            Text(account.name)
                                .tag(Optional(account.id))
                        }
                    }
                }
            }

            Section("备注与标签") {
                TextField("备注、商户或用途", text: $note, axis: .vertical)
                    .lineLimit(2...5)
                TextField("标签，用空格或逗号分隔", text: $tagsText)
                if !attachmentIDs.isEmpty {
                    Label("已关联 \(attachmentIDs.count) 个附件", systemImage: "paperclip")
                        .font(.footnote)
                        .foregroundStyle(Color.catRose)
                }
            }

            if kind == .expense {
                Section("特殊标记") {
                    Toggle("这是退款", isOn: $isRefund)
                    Toggle("公司/朋友会报销", isOn: $isReimbursed)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.catBackground.ignoresSafeArea())
        .navigationTitle(existing == nil ? "记一笔" : "编辑账单")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    save()
                }
                .fontWeight(.semibold)
            }
        }
        .alert("还差一点点", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .onChange(of: kind) { _, next in
            if let first = store.categories.first(where: { $0.kind == next }) {
                categoryID = first.id
            }
        }
        .onAppear {
            categoryID = categoryID ?? filteredCategories.first?.id
            accountID = accountID ?? store.accounts.first?.id
            toAccountID = toAccountID ?? store.accounts.dropFirst().first?.id
        }
    }

    private var filteredCategories: [LedgerCategory] {
        store.categories.filter { $0.kind == kind }
    }

    private func save() {
        guard let amountCents = cents(from: amount) else {
            alertMessage = "请输入有效金额。"
            return
        }
        guard let accountID = accountID ?? store.accounts.first?.id else {
            alertMessage = "请先创建一个账户。"
            return
        }
        if kind == .transfer && toAccountID == accountID {
            alertMessage = "转入账户不能和转出账户相同。"
            return
        }

        let transaction = LedgerTransaction(
            id: existing?.id ?? UUID(),
            kind: kind,
            amountCents: amountCents,
            categoryID: kind == .transfer ? nil : (categoryID ?? filteredCategories.first?.id),
            accountID: accountID,
            toAccountID: kind == .transfer ? toAccountID : nil,
            date: date,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: parseTags(tagsText),
            attachmentIDs: attachmentIDs,
            isRefund: kind == .expense && isRefund,
            isReimbursed: kind == .expense && isReimbursed,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date()
        )

        if existing == nil {
            store.addTransaction(transaction)
        } else {
            store.updateTransaction(transaction)
        }
        dismiss()
    }
}
