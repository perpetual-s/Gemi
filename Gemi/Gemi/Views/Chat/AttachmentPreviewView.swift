import SwiftUI

/// Beautiful attachment preview with glass morphism and smooth animations
struct AttachmentPreviewView: View {
    @ObservedObject var attachmentManager: AttachmentManager
    @State private var hoveredAttachment: AttachmentManager.Attachment?
    @State private var expandedImage: NSImage?
    
    var body: some View {
        if !attachmentManager.attachments.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Label("Attachments", systemImage: "paperclip")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            attachmentManager.clearAttachments()
                        }
                    } label: {
                        Text("Clear All")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.primaryAccent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                
                // Attachment grid
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(attachmentManager.attachments) { attachment in
                            AttachmentThumbnail(
                                attachment: attachment,
                                isHovered: hoveredAttachment?.id == attachment.id,
                                onRemove: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        attachmentManager.removeAttachment(attachment)
                                    }
                                },
                                onTap: {
                                    if case .image(let image) = attachment.type {
                                        expandedImage = image
                                    }
                                }
                            )
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    hoveredAttachment = hovering ? attachment : nil
                                }
                            }
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.Colors.cardBackground.opacity(0.3))
                    .background(
                        VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                            .opacity(0.5)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Theme.Colors.divider.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            ))
        }
        
        // Expanded image overlay
        if let image = expandedImage {
            ExpandedImageView(image: image) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    expandedImage = nil
                }
            }
        }
    }
}

// MARK: - Attachment Thumbnail

struct AttachmentThumbnail: View {
    let attachment: AttachmentManager.Attachment
    let isHovered: Bool
    let onRemove: () -> Void
    let onTap: () -> Void
    
    @State private var showRemoveButton = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Thumbnail content
            Button(action: onTap) {
                VStack(spacing: 6) {
                    // Thumbnail
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.Colors.cardBackground)
                            .frame(width: 80, height: 80)
                        
                        switch attachment.type {
                        case .image:
                            if let thumbnail = attachment.thumbnail {
                                Image(nsImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                        case .audio:
                            VStack(spacing: 4) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 24))
                                    .foregroundColor(Theme.Colors.primaryAccent)
                                
                                Text("Audio")
                                    .font(Theme.Typography.footnote)
                                    .foregroundColor(Theme.Colors.secondaryText)
                            }
                            
                        case .document:
                            VStack(spacing: 4) {
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Theme.Colors.primaryAccent)
                                
                                Text("Document")
                                    .font(Theme.Typography.footnote)
                                    .foregroundColor(Theme.Colors.secondaryText)
                            }
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isHovered ? Theme.Colors.primaryAccent.opacity(0.5) : Color.clear,
                                lineWidth: 2
                            )
                    )
                    .scaleEffect(isHovered ? 1.05 : 1.0)
                    
                    // File info
                    VStack(spacing: 2) {
                        Text(attachment.fileName)
                            .font(Theme.Typography.footnote)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Text(attachment.formattedSize)
                            .font(Theme.Typography.footnote)
                            .foregroundColor(Theme.Colors.tertiaryText)
                    }
                    .frame(width: 80)
                }
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    showRemoveButton = hovering
                }
            }
            
            // Remove button
            if showRemoveButton {
                Button(action: onRemove) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.windowBackground)
                            .frame(width: 20, height: 20)
                        
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                    }
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

// MARK: - Expanded Image View

struct ExpandedImageView: View {
    let image: NSImage
    let onDismiss: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            
            // Image
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = value
                        }
                        .onEnded { _ in
                            withAnimation(.spring()) {
                                if scale < 1.0 {
                                    scale = 1.0
                                } else if scale > 3.0 {
                                    scale = 3.0
                                }
                            }
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = value.translation
                        }
                        .onEnded { _ in
                            withAnimation(.spring()) {
                                offset = .zero
                            }
                        }
                )
                .onAppear {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isAnimating = true
                    }
                }
                .scaleEffect(isAnimating ? 1 : 0.8)
                .opacity(isAnimating ? 1 : 0)
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: onDismiss) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .background(
                                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                                        .clipShape(Circle())
                                )
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Progress View

struct AttachmentProgressView: View {
    @ObservedObject var attachmentManager: AttachmentManager
    
    var body: some View {
        if attachmentManager.isProcessing {
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.small)
                
                Text("Processing attachment...")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                
                if attachmentManager.processingProgress > 0 {
                    Text("\(Int(attachmentManager.processingProgress * 100))%")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.tertiaryText)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Theme.Colors.cardBackground.opacity(0.8))
                    .overlay(
                        Capsule()
                            .strokeBorder(Theme.Colors.divider.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity),
                removal: .scale(scale: 0.8).combined(with: .opacity)
            ))
        }
    }
}