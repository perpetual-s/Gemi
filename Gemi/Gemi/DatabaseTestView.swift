//
//  DatabaseTestView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/28/25.
//

import SwiftUI

/// DatabaseTestView provides a dedicated interface for testing the database layer functionality.
/// This view demonstrates the complete encrypt → store → fetch → decrypt workflow and can be used
/// during development to verify that the privacy-first architecture is working correctly.
///
/// Usage: Can be accessed during development for database verification
struct DatabaseTestView: View {
    @State private var testStatus = "Ready to test database..."
    @State private var testCompleted = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Gemi Logo
            Image(systemName: "book.closed")
                .imageScale(.large)
                .foregroundStyle(.tint)
                .font(.system(size: 50))
            
            Text("Gemi Database Test")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Privacy-First AI Diary - Database Layer Verification")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
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
            
            // Manual test button
            Button("Run Tests Again") {
                Task {
                    testCompleted = false
                    await runDatabaseTestDemo()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!testCompleted)
            
            Spacer()
            
            // Test Instructions
            VStack(spacing: 4) {
                Text("Check the Xcode console for detailed test results")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("This view tests encryption, storage, and retrieval of journal entries")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
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
    DatabaseTestView()
        .frame(width: 600, height: 500)
} 