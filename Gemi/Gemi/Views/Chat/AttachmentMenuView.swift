import SwiftUI
import UniformTypeIdentifiers

/// Beautiful attachment menu with smooth animations
struct AttachmentMenuView: View {
    @ObservedObject var attachmentManager: AttachmentManager
    @Binding var showAudioRecorder: Bool
    @Environment(\.dismiss) private var dismiss
    
    @State private var hoveredOption: AttachmentOption?
    @State private var isFileImporterPresented = false
    @State private var selectedFileType: UTType = .image
    
    enum AttachmentOption: CaseIterable {
        case photo
        case audio
        
        var icon: String {
            switch self {
            case .photo: return "photo"
            case .audio: return "mic.fill"
            }
        }
        
        var title: String {
            switch self {
            case .photo: return "Photo"
            case .audio: return "Audio"
            }
        }
        
        var subtitle: String {
            switch self {
            case .photo: return "Add images"
            case .audio: return "Record voice"
            }
        }
        
        var color: Color {
            switch self {
            case .photo: return .blue
            case .audio: return .orange
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(AttachmentOption.allCases, id: \.self) { option in
                AttachmentOptionButton(
                    option: option,
                    isHovered: hoveredOption == option,
                    action: {
                        handleSelection(option)
                    }
                )
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        hoveredOption = hovering ? option : nil
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.Colors.windowBackground)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: getAllowedTypes(),
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
    }
    
    private func handleSelection(_ option: AttachmentOption) {
        switch option {
        case .photo:
            selectedFileType = .image
            isFileImporterPresented = true
            dismiss()
            
        case .audio:
            showAudioRecorder = true
            dismiss()
        }
    }
    
    private func getAllowedTypes() -> [UTType] {
        // Only support image types since we removed document support
        return [.png, .jpeg, .gif, .heif, .webP, .bmp, .tiff]
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                for url in urls {
                    do {
                        try await attachmentManager.addAttachment(from: url)
                    } catch {
                        print("Failed to add attachment: \(error)")
                    }
                }
            }
            
        case .failure(let error):
            print("File selection error: \(error)")
        }
    }
}

// MARK: - Attachment Option Button

struct AttachmentOptionButton: View {
    let option: AttachmentMenuView.AttachmentOption
    let isHovered: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(option.color.opacity(isHovered ? 0.15 : 0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: option.icon)
                        .font(.system(size: 16))
                        .foregroundColor(option.color)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(Theme.Typography.body)
                        .foregroundColor(.primary)
                    
                    Text(option.subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.tertiaryText)
                    .opacity(isHovered ? 1 : 0.5)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Theme.Colors.cardBackground : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Attachment Button

struct AttachmentButton: View {
    @State private var showMenu = false
    @ObservedObject var attachmentManager: AttachmentManager
    @Binding var showAudioRecorder: Bool
    
    var body: some View {
        Button {
            showMenu.toggle()
        } label: {
            ZStack {
                // Badge for attachment count
                if !attachmentManager.attachments.isEmpty {
                    Circle()
                        .fill(Theme.Colors.primaryAccent)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text("\(attachmentManager.attachments.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 8, y: -8)
                        .zIndex(1)
                }
                
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(
                        attachmentManager.attachments.isEmpty ?
                        Theme.Colors.secondaryText :
                        Theme.Colors.primaryAccent
                    )
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .buttonStyle(.plain)
        .help("Add attachment")
        .popover(isPresented: $showMenu, arrowEdge: .top) {
            AttachmentMenuView(
                attachmentManager: attachmentManager,
                showAudioRecorder: $showAudioRecorder
            )
            .frame(width: 220)
        }
    }
}