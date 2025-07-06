import SwiftUI

struct DiagnosticView: View {
    @State private var diagnosticResults: [DiagnosticService.DiagnosticResult] = []
    @State private var isRunning = false
    @State private var showReport = false
    @State private var reportText = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("System Diagnostics")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Run diagnostics to check all system components")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if isRunning {
                ProgressView("Running diagnostics...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
            } else if !diagnosticResults.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(diagnosticResults, id: \.component) { result in
                            DiagnosticResultRow(result: result)
                        }
                    }
                    .padding()
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            
            HStack(spacing: 20) {
                Button(action: runDiagnostics) {
                    Label("Run Diagnostics", systemImage: "stethoscope")
                        .frame(width: 180)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning)
                
                if !diagnosticResults.isEmpty {
                    Button(action: { showReport = true }) {
                        Label("View Report", systemImage: "doc.text")
                            .frame(width: 180)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.top)
            
            Spacer()
        }
        .padding()
        .frame(width: 600, height: 500)
        .sheet(isPresented: $showReport) {
            ReportView(reportText: reportText)
        }
    }
    
    private func runDiagnostics() {
        isRunning = true
        diagnosticResults = []
        
        Task {
            let results = await DiagnosticService.shared.runDiagnostics()
            let report = await DiagnosticService.shared.generateReport(from: results)
            
            await MainActor.run {
                self.diagnosticResults = results
                self.reportText = report
                self.isRunning = false
            }
        }
    }
}

struct DiagnosticResultRow: View {
    let result: DiagnosticService.DiagnosticResult
    
    private var statusIcon: String {
        switch result.status {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .failure: return "xmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch result.status {
        case .success: return .green
        case .warning: return .orange
        case .failure: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.title2)
                
                Text(result.component)
                    .font(.headline)
                
                Spacer()
            }
            
            Text(result.message)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            if let details = result.details {
                Text(details)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct ReportView: View {
    let reportText: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            HStack {
                Text("Diagnostic Report")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            ScrollView {
                Text(reportText)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
            }
            
            HStack {
                Button(action: copyReport) {
                    Label("Copy Report", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: saveReport) {
                    Label("Save Report", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
    }
    
    private func copyReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(reportText, forType: .string)
    }
    
    private func saveReport() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "gemi-diagnostic-report.txt"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? reportText.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}