import SwiftUI

struct MenuBarPopover: View {
    let viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("ScreenPut")
                    .font(.headline)
                Spacer()
                if viewModel.isUploading {
                    ProgressView()
                        .controlSize(.small)
                    Text("Uploading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Cancel") {
                        viewModel.cancelUpload()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .font(.caption)
                }
            }
            .padding()

            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                        .lineLimit(2)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            Divider()

            // Screenshot list
            if viewModel.recentScreenshots.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No screenshots yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Take a screenshot and it will appear here")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.recentScreenshots) { record in
                            ScreenshotRow(record: record) {
                                viewModel.copyURL(record.remoteURL)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }

            Divider()

            // Footer
            HStack {
                SettingsLink {
                    Text("Settings...")
                }
                .buttonStyle(.borderless)

                Spacer()

                Text("\(viewModel.uploadCount) uploaded")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }
}
