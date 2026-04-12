import SwiftUI

struct ScreenshotRow: View {
    let record: ScreenshotRecord
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Thumbnail
            Group {
                if record.fileType == .png || record.fileType == .jpg {
                    AsyncImage(url: record.remoteURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            thumbnailPlaceholder
                        }
                    }
                } else {
                    thumbnailPlaceholder
                }
            }
            .frame(width: 48, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(record.remoteURL.absoluteString)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    Text(formattedDate)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(formattedSize)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy URL")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary.opacity(0.5))
        )
    }

    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.quaternary)
            .overlay {
                Image(systemName: record.fileType == .mov ? "video.fill" : "photo")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
    }

    private var formattedDate: String {
        let calendar = Calendar.current
        let now = Date()
        let date = record.uploadedAt

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeString = timeFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            return timeString
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday \(timeString)"
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "MMM d"
            return "\(dayFormatter.string(from: date)) \(timeString)"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "MMM d, yyyy"
            return "\(dayFormatter.string(from: date)) \(timeString)"
        }
    }

    private var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: record.fileSizeBytes)
    }
}
