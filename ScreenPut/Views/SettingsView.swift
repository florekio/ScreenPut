import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct SettingsView: View {
    @Bindable var viewModel: AppViewModel
    @State private var shareXJSONInput: String = ""
    @State private var shareXImportError: String?

    var body: some View {
        TabView {
            storageTab
                .tabItem { Label("Storage", systemImage: "cloud") }

            generalTab
                .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 480, height: 420)
    }

    // MARK: - Storage Tab

    private var storageTab: some View {
        Form {
            Picker("Provider", selection: $viewModel.storageProvider) {
                ForEach(StorageProvider.allCases, id: \.self) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 8)

            switch viewModel.storageProvider {
            case .s3:
                s3Fields
            case .azure:
                azureFields
            case .shareX:
                shareXFields
            }
        }
        .padding()
    }

    private var s3Fields: some View {
        Group {
            TextField("Bucket", text: $viewModel.s3Config.bucket)
                .textFieldStyle(.roundedBorder)
            TextField("Region", text: $viewModel.s3Config.region)
                .textFieldStyle(.roundedBorder)
            TextField("Access Key ID", text: $viewModel.s3Config.accessKeyID)
                .textFieldStyle(.roundedBorder)
            SecureField("Secret Access Key", text: $viewModel.s3Config.secretAccessKey)
                .textFieldStyle(.roundedBorder)
            TextField("Path Prefix", text: $viewModel.s3Config.pathPrefix)
                .textFieldStyle(.roundedBorder)
            TextField("Custom Domain", text: $viewModel.s3Config.customDomain,
                      prompt: Text("e.g. cdn.example.com (optional)"))
                .textFieldStyle(.roundedBorder)

            if viewModel.s3Config.isConfigured {
                Label("Configured", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            } else {
                Label("Missing required fields", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
    }

    private var azureFields: some View {
        Group {
            TextField("Account Name", text: $viewModel.azureConfig.accountName)
                .textFieldStyle(.roundedBorder)
            TextField("Container Name", text: $viewModel.azureConfig.containerName)
                .textFieldStyle(.roundedBorder)
            SecureField("SAS Token", text: $viewModel.azureConfig.sasToken)
                .textFieldStyle(.roundedBorder)

            if viewModel.azureConfig.isConfigured {
                Label("Configured", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            } else {
                Label("Missing required fields", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
    }

    private var shareXFields: some View {
        Group {
            GroupBox("Import ShareX Config") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paste a ShareX custom uploader JSON (.sxcu):")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $shareXJSONInput)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.3))
                        )
                    HStack {
                        Button("Import JSON") {
                            importShareXJSON()
                        }
                        Button("Import from File...") {
                            importShareXFile()
                        }
                        Spacer()
                        if let error = shareXImportError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }

            TextField("Name", text: $viewModel.shareXConfig.name)
                .textFieldStyle(.roundedBorder)
            TextField("Request URL", text: $viewModel.shareXConfig.requestURL)
                .textFieldStyle(.roundedBorder)
            TextField("File Form Name", text: $viewModel.shareXConfig.fileFormName)
                .textFieldStyle(.roundedBorder)
            TextField("Response URL Pattern", text: $viewModel.shareXConfig.responseURLPattern,
                      prompt: Text("e.g. $json:data.link$"))
                .textFieldStyle(.roundedBorder)

            if !viewModel.shareXConfig.headers.isEmpty {
                GroupBox("Headers") {
                    ForEach(Array(viewModel.shareXConfig.headers.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text(key)
                                .font(.caption)
                                .frame(width: 120, alignment: .leading)
                            if viewModel.shareXConfig.secretHeaderKeys.contains(key) {
                                SecureField("value", text: shareXHeaderBinding(for: key))
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                TextField("value", text: shareXHeaderBinding(for: key))
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                }
            }

            if viewModel.shareXConfig.isConfigured {
                Label("Configured", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            } else {
                Label("Missing required fields", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
    }

    private func importShareXJSON() {
        shareXImportError = nil
        guard let data = shareXJSONInput.data(using: .utf8) else {
            shareXImportError = "Invalid text"
            return
        }
        do {
            viewModel.shareXConfig = try ShareXConfig.fromShareXJSON(data)
        } catch {
            shareXImportError = error.localizedDescription
        }
    }

    private func importShareXFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                viewModel.shareXConfig = try ShareXConfig.fromShareXJSON(data)
                shareXJSONInput = String(data: data, encoding: .utf8) ?? ""
            } catch {
                shareXImportError = error.localizedDescription
            }
        }
    }

    private func shareXHeaderBinding(for key: String) -> Binding<String> {
        Binding(
            get: { viewModel.shareXConfig.headers[key] ?? "" },
            set: { viewModel.shareXConfig.headers[key] = $0 }
        )
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Toggle("Delete original after upload", isOn: $viewModel.deleteAfterUpload)

            Toggle("Resize images before upload", isOn: $viewModel.resizeImages)

            if viewModel.resizeImages {
                HStack {
                    Text("Scale: \(Int(viewModel.resizeScale * 100))%")
                        .frame(width: 80, alignment: .leading)
                    Slider(value: $viewModel.resizeScale, in: 0.25...1.0, step: 0.05)
                }
            }

            Divider()

            LabeledContent("Screenshot Folder") {
                Text(ScreenshotLocationManager.screenshotDirectory.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Toggle("Launch at Login", isOn: $viewModel.launchAtLogin)

            Divider()

            HStack {
                Spacer()
                Button("Apply Screenshot Location") {
                    ScreenshotLocationManager.ensureConfigured()
                }
            }
        }
        .padding()
    }
}
