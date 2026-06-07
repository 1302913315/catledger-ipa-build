import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class LedgerStore: ObservableObject {
    @Published var transactions: [LedgerTransaction] = []
    @Published var categories: [LedgerCategory] = []
    @Published var accounts: [LedgerAccount] = []
    @Published var budgets: [LedgerBudget] = []
    @Published var assets: [AssetLiability] = []
    @Published var attachments: [LedgerAttachment] = []

    private let fileName = "cat-ledger-store.json"

    init() {
        load()
        seedDefaultsIfNeeded()
    }

    var monthTransactions: [LedgerTransaction] {
        transactions
            .filter { $0.date.monthKey == Date().monthKey }
            .sorted { $0.date > $1.date }
    }

    var monthlyExpenseCents: Int {
        monthTransactions
            .filter { $0.kind == .expense && !$0.isRefund && !$0.isReimbursed }
            .reduce(0) { $0 + $1.amountCents }
    }

    var monthlyIncomeCents: Int {
        monthTransactions
            .filter { $0.kind == .income }
            .reduce(0) { $0 + $1.amountCents }
    }

    var monthBalanceCents: Int {
        monthlyIncomeCents - monthlyExpenseCents
    }

    var enabledBudgets: [LedgerBudget] {
        budgets.filter { $0.isEnabled && $0.monthKey == Date().monthKey }
    }

    var currentBudgetCents: Int {
        enabledBudgets.reduce(0) { $0 + $1.amountCents }
    }

    var currentBudgetProgress: Double {
        guard currentBudgetCents > 0 else { return 0 }
        return min(1.2, Double(monthlyExpenseCents) / Double(currentBudgetCents))
    }

    var netWorthCents: Int {
        let accountTotal = accounts
            .filter(\.includeInNetWorth)
            .reduce(0) { $0 + balance(for: $1.id) }
        let assetTotal = assets.reduce(0) { total, item in
            total + (item.kind == .asset ? item.balanceCents : -item.balanceCents)
        }
        return accountTotal + assetTotal
    }

    func addTransaction(_ transaction: LedgerTransaction) {
        transactions.append(transaction)
        transactions.sort { $0.date > $1.date }
        save()
    }

    func updateTransaction(_ transaction: LedgerTransaction) {
        guard let index = transactions.firstIndex(where: { $0.id == transaction.id }) else {
            return
        }
        var updated = transaction
        updated.updatedAt = Date()
        transactions[index] = updated
        transactions.sort { $0.date > $1.date }
        save()
    }

    func deleteTransactions(at offsets: IndexSet, from source: [LedgerTransaction]) {
        let ids = offsets.map { source[$0].id }
        transactions.removeAll { ids.contains($0.id) }
        save()
    }

    func deleteTransaction(id: UUID) {
        transactions.removeAll { $0.id == id }
        save()
    }

    func addCategory(_ category: LedgerCategory) {
        categories.append(category)
        categories.sort { $0.sortOrder < $1.sortOrder }
        save()
    }

    func updateCategory(_ category: LedgerCategory) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else {
            return
        }
        categories[index] = category
        categories.sort { $0.sortOrder < $1.sortOrder }
        save()
    }

    func deleteCategory(id: UUID) {
        transactions = transactions.map { item in
            var updated = item
            if updated.categoryID == id {
                updated.categoryID = nil
            }
            return updated
        }
        categories.removeAll { $0.id == id }
        save()
    }

    func addAccount(_ account: LedgerAccount) {
        accounts.append(account)
        save()
    }

    func updateAccount(_ account: LedgerAccount) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else {
            return
        }
        accounts[index] = account
        save()
    }

    func deleteAccount(id: UUID) {
        guard accounts.count > 1 else {
            return
        }
        let fallback = accounts.first { $0.id != id }?.id
        transactions = transactions.compactMap { item in
            if item.accountID == id && fallback == nil {
                return nil
            }
            var updated = item
            if updated.accountID == id, let fallback {
                updated.accountID = fallback
            }
            if updated.toAccountID == id {
                updated.toAccountID = nil
            }
            return updated
        }
        accounts.removeAll { $0.id == id }
        save()
    }

    func upsertBudget(_ budget: LedgerBudget) {
        if let index = budgets.firstIndex(where: { $0.id == budget.id }) {
            budgets[index] = budget
        } else {
            budgets.append(budget)
        }
        save()
    }

    func deleteBudget(id: UUID) {
        budgets.removeAll { $0.id == id }
        save()
    }

    func addAsset(_ asset: AssetLiability) {
        assets.append(asset)
        save()
    }

    func updateAsset(_ asset: AssetLiability) {
        guard let index = assets.firstIndex(where: { $0.id == asset.id }) else {
            return
        }
        assets[index] = asset
        save()
    }

    func deleteAsset(id: UUID) {
        assets.removeAll { $0.id == id }
        save()
    }

    func addAttachment(localPath: String, ocrText: String) -> LedgerAttachment {
        let attachment = LedgerAttachment(localPath: localPath, ocrText: ocrText)
        attachments.append(attachment)
        save()
        return attachment
    }

    func saveAttachment(data: Data, fileExtension: String, ocrText: String) -> LedgerAttachment? {
        let directory = attachmentsDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let normalizedExtension = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ".")).isEmpty
            ? "jpg"
            : fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let url = directory.appendingPathComponent("\(UUID().uuidString).\(normalizedExtension)")
        do {
            try data.write(to: url, options: .atomic)
            return addAttachment(localPath: url.path, ocrText: ocrText)
        } catch {
            return nil
        }
    }

    func category(for id: UUID?) -> LedgerCategory? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    func account(for id: UUID?) -> LedgerAccount? {
        guard let id else { return nil }
        return accounts.first { $0.id == id }
    }

    func balance(for accountID: UUID) -> Int {
        guard let account = accounts.first(where: { $0.id == accountID }) else {
            return 0
        }

        return transactions.reduce(account.openingBalanceCents) { balance, item in
            switch item.kind {
            case .income:
                return item.accountID == accountID ? balance + item.amountCents : balance
            case .expense:
                return item.accountID == accountID ? balance - item.amountCents : balance
            case .transfer:
                if item.accountID == accountID {
                    return balance - item.amountCents
                }
                if item.toAccountID == accountID {
                    return balance + item.amountCents
                }
                return balance
            }
        }
    }

    func groupedTransactions(_ source: [LedgerTransaction]) -> [(String, [LedgerTransaction])] {
        let grouped = Dictionary(grouping: source) { $0.date.dayKey }
        return grouped
            .map { key, value in
                (key, value.sorted { $0.date > $1.date })
            }
            .sorted { left, right in
                guard let firstLeft = left.1.first?.date, let firstRight = right.1.first?.date else {
                    return left.0 > right.0
                }
                return firstLeft > firstRight
            }
    }

    func expensesByCategory(monthKey: String = Date().monthKey) -> [CategorySpending] {
        let expenses = transactions.filter {
            $0.kind == .expense && $0.date.monthKey == monthKey && !$0.isRefund && !$0.isReimbursed
        }
        let grouped = Dictionary(grouping: expenses) { $0.categoryID }
        return grouped.compactMap { id, items in
            guard let category = category(for: id) else { return nil }
            return CategorySpending(category: category, amountCents: items.reduce(0) { $0 + $1.amountCents })
        }
        .sorted { $0.amountCents > $1.amountCents }
    }

    func trend(days: Int = 7) -> [(Date, Int, Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<days).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let items = transactions.filter { calendar.isDate($0.date, inSameDayAs: date) }
            let expense = items.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amountCents }
            let income = items.filter { $0.kind == .income }.reduce(0) { $0 + $1.amountCents }
            return (date, income, expense)
        }
    }

    func importCSV(text: String) -> ImportResult {
        let rows = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var imported = 0
        var failures: [String] = []
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"

        let dataRows = rows.dropFirst(rows.first?.contains("金额") == true ? 1 : 0)

        for (index, row) in dataRows.enumerated() {
            let columns = splitCSV(row)
            guard columns.count >= 4 else {
                failures.append("第 \(index + 1) 行列数不足")
                continue
            }

            let date = formatter.date(from: columns[0]) ?? Date()
            let kind = TransactionKind(rawValue: columns[1]) ?? (columns[2].contains("-") ? .expense : .income)
            guard let amount = cents(from: columns[2].replacingOccurrences(of: "-", with: "")) else {
                failures.append("第 \(index + 1) 行金额无效")
                continue
            }

            let category = categories.first { $0.name == columns[3] && $0.kind == kind }
                ?? categories.first { $0.kind == kind }
            let importedAccountName = columns[safe: 4]
            let matchedAccount = importedAccountName.flatMap { name in
                accounts.first { $0.name == name }
            }
            guard let account = matchedAccount ?? accounts.first else {
                failures.append("第 \(index + 1) 行缺少账户")
                continue
            }

            let transaction = LedgerTransaction(
                kind: kind,
                amountCents: amount,
                categoryID: category?.id,
                accountID: account.id,
                toAccountID: nil,
                date: date,
                note: columns[safe: 5] ?? "",
                tags: parseTags(columns[safe: 6] ?? ""),
                attachmentIDs: [],
                isRefund: false,
                isReimbursed: false
            )
            transactions.append(transaction)
            imported += 1
        }

        transactions.sort { $0.date > $1.date }
        save()
        return ImportResult(importedCount: imported, failedRows: failures)
    }

    func exportCSV() -> String {
        let header = "日期,类型,金额,分类,账户,备注,标签"
        let rows = transactions
            .sorted { $0.date > $1.date }
            .map { item in
                [
                    Date.csvDateFormatter.string(from: item.date),
                    item.kind.rawValue,
                    amountText(item.amountCents),
                    category(for: item.categoryID)?.name ?? "",
                    account(for: item.accountID)?.name ?? "",
                    item.note,
                    item.tags.joined(separator: " ")
                ]
                .map(escapeCSV)
                .joined(separator: ",")
            }
        return ([header] + rows).joined(separator: "\n")
    }

    func backupJSON() -> String {
        let snapshot = LedgerSnapshot(
            transactions: transactions,
            categories: categories,
            accounts: accounts,
            budgets: budgets,
            assets: assets,
            attachments: attachments
        )

        guard let data = try? JSONEncoder.pretty.encode(snapshot) else {
            return "{}"
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    func restoreBackup(text: String) throws {
        let data = Data(text.utf8)
        let snapshot = try JSONDecoder.ledger.decode(LedgerSnapshot.self, from: data)
        transactions = snapshot.transactions.sorted { $0.date > $1.date }
        categories = snapshot.categories.sorted { $0.sortOrder < $1.sortOrder }
        accounts = snapshot.accounts
        budgets = snapshot.budgets
        assets = snapshot.assets
        attachments = snapshot.attachments
        save()
    }

    func temporaryFileURL(named name: String, contents: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        if let data = contents.data(using: .utf8) {
            try? data.write(to: url, options: .atomic)
        }
        return url
    }

    private func splitCSV(_ row: String) -> [String] {
        var result: [String] = []
        var current = ""
        var isQuoted = false
        var iterator = row.makeIterator()

        while let char = iterator.next() {
            if char == "\"" {
                isQuoted.toggle()
            } else if char == "," && !isQuoted {
                result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        return result
    }

    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private func load() {
        let url = storeURL
        guard let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder.ledger.decode(LedgerSnapshot.self, from: data) else {
            return
        }
        transactions = snapshot.transactions.sorted { $0.date > $1.date }
        categories = snapshot.categories.sorted { $0.sortOrder < $1.sortOrder }
        accounts = snapshot.accounts
        budgets = snapshot.budgets
        assets = snapshot.assets
        attachments = snapshot.attachments
    }

    private func save() {
        let snapshot = LedgerSnapshot(
            transactions: transactions,
            categories: categories,
            accounts: accounts,
            budgets: budgets,
            assets: assets,
            attachments: attachments
        )

        guard let data = try? JSONEncoder.pretty.encode(snapshot) else {
            return
        }
        try? data.write(to: storeURL, options: .atomic)
    }

    private var storeURL: URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return directory.appendingPathComponent(fileName)
    }

    private var attachmentsDirectory: URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return directory.appendingPathComponent("Attachments", isDirectory: true)
    }

    private func seedDefaultsIfNeeded() {
        if categories.isEmpty {
            categories = Self.defaultCategories
        }
        if accounts.isEmpty {
            accounts = Self.defaultAccounts
        }
        if budgets.isEmpty {
            budgets = [
                LedgerBudget(
                    monthKey: Date().monthKey,
                    categoryID: nil,
                    amountCents: 500_000,
                    warningRatio: 0.85,
                    isEnabled: false
                )
            ]
        }
        if assets.isEmpty {
            assets = [
                AssetLiability(name: "储蓄目标", kind: .asset, balanceCents: 0, colorHex: "#BDEEDB", note: "可以记录应急金、旅行基金等"),
                AssetLiability(name: "信用卡待还", kind: .liability, balanceCents: 0, colorHex: "#F178A6", note: "用于观察净资产")
            ]
        }
        save()
    }

    static var defaultCategories: [LedgerCategory] {
        [
            LedgerCategory(name: "餐饮", symbolName: "fork.knife", colorHex: "#F178A6", kind: .expense, sortOrder: 0),
            LedgerCategory(name: "交通", symbolName: "tram.fill", colorHex: "#F2A65A", kind: .expense, sortOrder: 1),
            LedgerCategory(name: "购物", symbolName: "bag.fill", colorHex: "#C783FF", kind: .expense, sortOrder: 2),
            LedgerCategory(name: "住房", symbolName: "house.fill", colorHex: "#7FC8F8", kind: .expense, sortOrder: 3),
            LedgerCategory(name: "娱乐", symbolName: "gamecontroller.fill", colorHex: "#FFB6C9", kind: .expense, sortOrder: 4),
            LedgerCategory(name: "医疗", symbolName: "cross.case.fill", colorHex: "#57BFA1", kind: .expense, sortOrder: 5),
            LedgerCategory(name: "学习", symbolName: "book.fill", colorHex: "#91A7FF", kind: .expense, sortOrder: 6),
            LedgerCategory(name: "工资", symbolName: "banknote.fill", colorHex: "#57BFA1", kind: .income, sortOrder: 7),
            LedgerCategory(name: "兼职", symbolName: "briefcase.fill", colorHex: "#F2A65A", kind: .income, sortOrder: 8),
            LedgerCategory(name: "理财", symbolName: "chart.line.uptrend.xyaxis", colorHex: "#7FC8F8", kind: .income, sortOrder: 9)
        ]
    }

    static var defaultAccounts: [LedgerAccount] {
        [
            LedgerAccount(name: "现金", kind: .cash, openingBalanceCents: 0, colorHex: "#F2A65A", includeInNetWorth: true),
            LedgerAccount(name: "银行卡", kind: .bank, openingBalanceCents: 0, colorHex: "#7FC8F8", includeInNetWorth: true),
            LedgerAccount(name: "微信", kind: .wallet, openingBalanceCents: 0, colorHex: "#57BFA1", includeInNetWorth: true),
            LedgerAccount(name: "支付宝", kind: .wallet, openingBalanceCents: 0, colorHex: "#91A7FF", includeInNetWorth: true),
            LedgerAccount(name: "信用卡", kind: .credit, openingBalanceCents: 0, colorHex: "#F178A6", includeInNetWorth: true)
        ]
    }
}

private struct LedgerSnapshot: Codable {
    var transactions: [LedgerTransaction]
    var categories: [LedgerCategory]
    var accounts: [LedgerAccount]
    var budgets: [LedgerBudget]
    var assets: [AssetLiability]
    var attachments: [LedgerAttachment]
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var ledger: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
