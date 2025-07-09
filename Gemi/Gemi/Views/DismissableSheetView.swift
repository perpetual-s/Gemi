import SwiftUI

/// A wrapper view that allows dismissing a sheet by clicking the background
struct DismissableSheetView<Content: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder let content: Content
    
    var body: some View {
        ZStack {
            // Transparent background that captures clicks
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // Content with proper background and corner radius
            content
                .background(Color(NSColor.windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                .padding(40)
                .onTapGesture {
                    // Prevent dismissal when clicking on content
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BackgroundBlurView())
    }
}

/// Background blur effect for macOS
struct BackgroundBlurView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// View modifier for dismissable sheet presentation
struct DismissableSheet<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder let sheetContent: () -> SheetContent
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                DismissableSheetView(isPresented: $isPresented) {
                    sheetContent()
                }
                .background(Color.clear) // Make sheet background transparent
            }
    }
}

// Extension for easier usage
extension View {
    func dismissableSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(DismissableSheet(isPresented: isPresented, sheetContent: content))
    }
}