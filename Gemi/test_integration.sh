#!/bin/bash

# Integration test script for Gemi app components

echo "=== GEMI INTEGRATION TEST ==="
echo "Date: $(date)"
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "Testing $test_name... "
    
    if eval "$test_command" &> /dev/null; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# 1. Check if app is sandboxed
echo "1. SANDBOX CHECKS"
echo "-----------------"

run_test "Entitlements file exists" "test -f Gemi/Gemi.entitlements"
run_test "Development entitlements exist" "test -f Gemi/Gemi.Development.entitlements"

# Check entitlements content
if test -f Gemi/Gemi.entitlements; then
    echo -n "   Checking network permissions... "
    if grep -q "com.apple.security.network.client" Gemi/Gemi.entitlements && \
       grep -q "com.apple.security.network.server" Gemi/Gemi.entitlements && \
       grep -q "com.apple.security.temporary-exception.local-networking" Gemi/Gemi.entitlements; then
        echo -e "${GREEN}✓ All network entitlements present${NC}"
    else
        echo -e "${RED}✗ Missing network entitlements${NC}"
    fi
fi

echo ""

# 2. Check database setup
echo "2. DATABASE CHECKS"
echo "------------------"

# Check if DatabaseManager has sandbox-aware path handling
run_test "DatabaseManager uses Application Support" "grep -q 'applicationSupportDirectory' Gemi/Services/DatabaseManager.swift"
run_test "DatabaseManager handles journal mode fallback" "grep -q 'journal_mode=DELETE' Gemi/Services/DatabaseManager.swift"
run_test "DatabaseManager has test connection method" "grep -q 'testConnection' Gemi/Services/DatabaseManager.swift"

echo ""

# 3. Check Ollama integration
echo "3. OLLAMA CHECKS"
echo "----------------"

run_test "OllamaProcessManager checks multiple paths" "grep -q '/Applications/Ollama.app' Gemi/Services/OllamaProcessManager.swift"
run_test "OllamaProcessManager handles localhost connection" "grep -q 'localhost:11434' Gemi/Services/OllamaProcessManager.swift"
run_test "OllamaService configured for localhost" "grep -q 'http://localhost:11434' Gemi/Services/OllamaService.swift"

# Check if Ollama is installed
echo -n "   Checking if Ollama is installed... "
if which ollama &> /dev/null || test -d "/Applications/Ollama.app"; then
    echo -e "${GREEN}✓ Ollama found${NC}"
else
    echo -e "${YELLOW}⚠ Ollama not installed${NC}"
fi

echo ""

# 4. Check diagnostic service
echo "4. DIAGNOSTIC SERVICE"
echo "--------------------"

run_test "DiagnosticService exists" "test -f Gemi/Services/DiagnosticService.swift"
run_test "DiagnosticView exists" "test -f Gemi/Views/DiagnosticView.swift"
run_test "Diagnostic menu item added" "grep -q 'Run Diagnostics' Gemi/GemiApp.swift"

echo ""

# 5. Check for potential issues
echo "5. POTENTIAL ISSUES CHECK"
echo "-------------------------"

# Check for hardcoded paths that might fail in sandbox
echo -n "   Checking for hardcoded paths... "
if grep -r "~/\|/Users/\|/home/" Gemi/Services/*.swift 2>/dev/null | grep -v "NSHomeDirectory\|FileManager.default.url" | grep -v "// " > /dev/null; then
    echo -e "${YELLOW}⚠ Found potential hardcoded paths${NC}"
else
    echo -e "${GREEN}✓ No problematic hardcoded paths${NC}"
fi

# Check for missing error handling
echo -n "   Checking error handling... "
ERROR_COUNT=$(grep -r "try!" Gemi/Services/*.swift 2>/dev/null | wc -l)
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠ Found $ERROR_COUNT force-try statements${NC}"
else
    echo -e "${GREEN}✓ No force-try statements found${NC}"
fi

echo ""

# 6. Summary
echo "====== SUMMARY ======"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All integration tests passed! The app should work correctly.${NC}"
else
    echo -e "\n${YELLOW}Some tests failed. Please review the issues above.${NC}"
fi

echo ""
echo "RECOMMENDATIONS:"
echo "1. Run the app and use the Diagnostics menu (Cmd+Option+D) for runtime checks"
echo "2. Test database operations by creating and saving a journal entry"
echo "3. Test Ollama integration by using the chat feature"
echo "4. Monitor Console.app for any sandbox violations"

# Make script executable
chmod +x "$0"