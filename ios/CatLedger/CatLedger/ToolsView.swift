import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import Vision

#if canImport(UIKit)
import UIKit
#endif

struct ToolsView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var recognizedText = ""
    @State private var recognizedAttachmentIDs: [UUID] = []
    @State private var showingOCRTransaction = false
    @State private var showingImporter = false
    @State private var showingRestoreImporter = false
    @State private var importResult: ImportResult?
    @State private var alertMessage: String?
    @State private var exportURL: URL?

    var body: some View {
        CatPage(title: "工具箱", subtitle: "导入、识别、备份都在这里") {
            ocrCard
            importCard
            exportCard
            backupCard

            if let importResult {
                CatCard {
                    Text(importResult.summary)
                        .font(.headline)
                        .foregroundStyle(Color.catInk)
                    ForEach(importResult.failedRows.prefix(6), id: \.self) { row in
                        Text(row)
                            .font(.caption)
                            .foregroundStyle(Color.catSubtext)
                    }
                }
            }
        }
        .onChange(of: selectedPhoto) { _, next in
            Task {
                await recognize(next)
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText, .text],
            allowsMultipleSelection: false
        ) { result in
            handleCSVImport(result)
        }
        .fileImporter(
            isPresented: $showingRestoreImporter,
            allowedContentTypes: [.json, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleRestore(result)
        }
        .sheet(isPresented: $showingOCRTransaction) {
            NavigationStack {
                TransactionEditorView(ocrText: recognizedText, attachmentIDs: recognizedAttachmentIDs)
            }
        }
        .sheet(item: Binding(
            get: { exportURL.map { ShareFile(url: $0) } },
            set: { value in exportURL = value?.url }
        )) { item in
            ShareSheet(items: [item.url])
        }
        .alert("提示", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var ocrCard: some View {
        CatCard {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("小票 OCR")
                        .font(.headline)
                        .foregroundStyle(Color.catInk)
                    Text("选择小票图片，本机识别后确认入账。")
                        .font(.subheadline)
                        .foregroundStyle(Color.catSubtext)
                }
                Spacer()
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("识别", systemImage: "doc.viewfinder.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.catRose)
            }

            if !recognizedText.isEmpty {
                Text(recognizedText)
                    .font(.caption)
                    .foregroundStyle(Color.catSubtext)
                    .lineLimit(5)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.catBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    showingOCRTransaction = true
                } label: {
                    Label("用识别结果记一笔", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.catRose)
            }
        }
    }

    private var importCard: some View {
        CatCard {
            Text("账单导入")
                .font(.headline)
                .foregroundStyle(Color.catInk)
            Text("支持 CSV 文本：日期,类型,金额,分类,账户,备注,标签。支付宝/微信账单可先导出并整理为这个格式。")
                .font(.subheadline)
                .foregroundStyle(Color.catSubtext)
            Button {
                showingImporter = true
            } label: {
                Label("导入 CSV", systemImage: "square.and.arrow.down.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.catPeach)
        }
    }

    private var exportCard: some View {
        CatCard {
            Text("数据导出")
                .font(.headline)
                .foregroundStyle(Color.catInk)
            Text("导出 CSV，可用 Numbers、Excel 或其他表格软件打开。")
                .font(.subheadline)
                .foregroundStyle(Color.catSubtext)
            HStack {
                Button {
                    exportURL = store.temporaryFileURL(named: "cat-ledger-\(Date().monthKey).csv", contents: store.exportCSV())
                } label: {
                    Label("CSV", systemImage: "tablecells.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.catRose)

                Button {
                    if let url = makePDFReport() {
                        exportURL = url
                    } else {
                        alertMessage = "PDF 导出需要在 iPhone 或 iOS 模拟器上运行。"
                    }
                } label: {
                    Label("PDF", systemImage: "doc.richtext.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.catRose)
            }
        }
    }

    private var backupCard: some View {
        CatCard {
            Text("本地备份")
                .font(.headline)
                .foregroundStyle(Color.catInk)
            Text("生成 JSON 备份文件，也可以从备份恢复。")
                .font(.subheadline)
                .foregroundStyle(Color.catSubtext)

            HStack {
                Button {
                    exportURL = store.temporaryFileURL(named: "cat-ledger-backup.json", contents: store.backupJSON())
                } label: {
                    Label("备份", systemImage: "externaldrive.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.catMint)

                Button {
                    showingRestoreImporter = true
                } label: {
                    Label("恢复", systemImage: "arrow.clockwise.icloud.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.catRose)
            }
        }
    }

    @MainActor
    private func recognize(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                alertMessage = "没有读取到图片。"
                return
            }
            #if canImport(UIKit)
            guard let image = UIImage(data: data), let cgImage = image.cgImage else {
                alertMessage = "图片格式暂不支持。"
                return
            }
            let request = VNRecognizeTextRequest()
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            request.recognitionLevel = .accurate
            try VNImageRequestHandler(cgImage: cgImage).perform([request])
            let observations = request.results as? [VNRecognizedTextObservation]
            let recognized = observations?
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n") ?? ""
            recognizedText = recognized
            if recognized.isEmpty {
                alertMessage = "没有识别到文字，可以换一张更清晰的小票。"
            }
            let persistedData = image.jpegData(compressionQuality: 0.86) ?? data
            if let attachment = store.saveAttachment(data: persistedData, fileExtension: "jpg", ocrText: recognized) {
                recognizedAttachmentIDs = [attachment.id]
            }
            #else
            alertMessage = "OCR 需要在 iPhone 或 iOS 模拟器上运行。"
            #endif
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func handleCSVImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                return
            }
            guard url.startAccessingSecurityScopedResource() else {
                alertMessage = "无法访问文件。"
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            let text = try String(contentsOf: url, encoding: .utf8)
            importResult = store.importCSV(text: text)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func handleRestore(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                return
            }
            guard url.startAccessingSecurityScopedResource() else {
                alertMessage = "无法访问文件。"
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            let text = try String(contentsOf: url, encoding: .utf8)
            try store.restoreBackup(text: text)
            alertMessage = "备份已恢复。"
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func makePDFReport() -> URL? {
        #if canImport(UIKit)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cat-ledger-\(Date().monthKey).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                var y: CGFloat = 36
                drawPDF("猫猫记账月报", x: 36, y: y, size: 24, weight: .bold)
                y += 38
                drawPDF("本月收入：\(moneyText(store.monthlyIncomeCents))", x: 36, y: y, size: 14, weight: .semibold)
                y += 24
                drawPDF("本月支出：\(moneyText(store.monthlyExpenseCents))", x: 36, y: y, size: 14, weight: .semibold)
                y += 24
                drawPDF("本月结余：\(moneyText(store.monthBalanceCents))", x: 36, y: y, size: 14, weight: .semibold)
                y += 34
                drawPDF("最近账单", x: 36, y: y, size: 18, weight: .bold)
                y += 28

                for item in store.transactions.prefix(24) {
                    let category = store.category(for: item.categoryID)?.name ?? item.kind.rawValue
                    let account = store.account(for: item.accountID)?.name ?? ""
                    let line = "\(Date.csvDateFormatter.string(from: item.date))  \(category)  \(account)  \(moneyText(item.amountCents))  \(item.note)"
                    drawPDF(line, x: 36, y: y, size: 11, weight: .regular)
                    y += 20
                    if y > 790 {
                        context.beginPage()
                        y = 36
                    }
                }
            }
            return url
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    #if canImport(UIKit)
    private func drawPDF(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: UIFont.Weight) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: UIColor(red: 0.28, green: 0.21, blue: 0.26, alpha: 1)
        ]
        (text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
    }
    #endif
}

private struct ShareFile: Identifiable {
    var id: URL { url }
    var url: URL
}

#if canImport(UIKit)
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
struct ShareSheet: View {
    var items: [Any]

    var body: some View {
        Text("分享功能需要在 iOS 上运行。")
    }
}
#endif
