import AppKit
import SwiftUI
import UniformTypeIdentifiers

public final class ExportSheetViewModel: ObservableObject {
    @Published public var selectedFormat: ExportSheet.ExportFormat = .png
    @Published public var quality: Double = 90.0
    @Published public var preserveTiffLayers: Bool = false
    @Published public var isExporting: Bool = false
    @Published public var exportError: String? = nil

    public init() {}
}

public struct ExportSheet: View {
    @ObservedObject var state: DocumentState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = ExportSheetViewModel()

    public enum ExportFormat: String, CaseIterable, Identifiable {
        case png = "PNG"
        case jpeg = "JPEG"
        case tiff = "TIFF"
        case webp = "WebP"

        public var id: String { rawValue }
        public var fileExtension: String {
            switch self {
            case .png: return "png"
            case .jpeg: return "jpg"
            case .tiff: return "tif"
            case .webp: return "webp"
            }
        }
        public var utType: UTType {
            switch self {
            case .png: return .png
            case .jpeg: return .jpeg
            case .tiff: return .tiff
            case .webp: return UTType(filenameExtension: "webp") ?? .image
            }
        }
    }

    public init(state: DocumentState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Export Image")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 14) {
                // Format Picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Format")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)

                    Picker("Format", selection: $vm.selectedFormat) {
                        ForEach(ExportFormat.allCases) { fmt in
                            Text(fmt.rawValue).tag(fmt)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // JPEG Quality Slider
                if vm.selectedFormat == .jpeg || vm.selectedFormat == .webp {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Quality")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(vm.quality))%")
                                .font(.system(.caption, design: .monospaced).weight(.semibold))
                        }

                        Slider(value: $vm.quality, in: 10...100, step: 1)
                    }
                }

                // TIFF Layers Toggle
                if vm.selectedFormat == .tiff {
                    Toggle("Preserve Photoshop Layer Structure", isOn: $vm.preserveTiffLayers)
                        .font(.caption)
                }

                // Output Dimensions Preview
                HStack {
                    Text("Output Resolution:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(state.metadata.width) × \(state.metadata.height) px")
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                }
                .padding(10)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))

                if let err = vm.exportError {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    promptSavePanel()
                } label: {
                    if vm.isExporting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Export...")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(vm.isExporting)
            }
        }
        .padding(24)
        .frame(width: 380)
    }

    private func promptSavePanel() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [vm.selectedFormat.utType]
        let baseName = state.documentURL?.deletingPathExtension().lastPathComponent ?? "Exported_Image"
        panel.nameFieldStringValue = "\(baseName).\(vm.selectedFormat.fileExtension)"

        if panel.runModal() == .OK, let targetURL = panel.url {
            vm.isExporting = true
            Task {
                do {
                    try await state.export(
                        to: targetURL,
                        format: vm.selectedFormat.fileExtension,
                        quality: Int(vm.quality)
                    )
                    await MainActor.run {
                        vm.isExporting = false
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        vm.exportError = error.localizedDescription
                        vm.isExporting = false
                    }
                }
            }
        }
    }
}
