#!/usr/bin/swift

import Foundation

// Reset onboarding status
UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
UserDefaults.standard.removeObject(forKey: "seenCoachMarks")
UserDefaults.standard.synchronize()

print("✅ Onboarding has been reset")
print("Launch Gemi to see the welcome screen again")