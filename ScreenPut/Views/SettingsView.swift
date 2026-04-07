import SwiftUI

@MainActor
struct SettingsView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        TabView {
            storageTab
                .tabItem { Label("Storage", systemImage: "cloud") }

            generalTab
                .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 480, height: 320)
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
