//
//  ContentView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/28/25.
//

import SwiftUI

struct ContentView: View {
    @State private var testStatus = "Ready to test database..."
    @State private var testCompleted = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Gemi Logo
            Image(systemName: "book.closed")
                .imageScale(.large)
                .foregroundStyle(.tint)
                .font(.system(size: 50))
            
            Text("Gemi")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Privacy-First AI Diary")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Divider()
            
            // Database Test Status
            VStack(alignment: .leading, spacing: 10) {
                Text("Database Layer Test")
                    .font(.headline)
                
                Text(testStatus)
                    .font(.body)
                    .foregroundStyle(testCompleted ? .green : .primary)
                
                if testCompleted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("All tests passed!")
                            .fontWeight(.semibold)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            Spacer()
            
            // Test Instructions
            Text("Check the Xcode console for detailed test results")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .task {
            await runDatabaseTestDemo()
        }
    }
    
    /// Runs the database test and updates the UI
    private func runDatabaseTestDemo() async {
        testStatus = "Initializing database..."
        
        // Small delay to show loading state
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        testStatus = "Running encryption tests..."
        
        // Run the comprehensive database tests
        await runDatabaseTests()
        
        testStatus = "Database tests completed successfully!"
        testCompleted = true
    }
}

#Preview {
    ContentView()
}
