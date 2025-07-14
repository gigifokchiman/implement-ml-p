#!/bin/bash
# Script to apply all security fixes to test-runner.sh and security-scan.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔧 Applying security fixes to test infrastructure..."

# Backup original files
cp "$SCRIPT_DIR/test-runner.sh" "$SCRIPT_DIR/test-runner.sh.backup.$(date +%s)"
cp "$SCRIPT_DIR/suites/security/security-scan.sh" "$SCRIPT_DIR/suites/security/security-scan.sh.backup.$(date +%s)"

echo "✅ Created backups of original files"

# Check if fixes are already applied
if grep -q "VALID_ENVIRONMENTS" "$SCRIPT_DIR/test-runner.sh"; then
    echo "⚠️  Security fixes appear to already be applied to test-runner.sh"
else
    echo "🔧 Applying fixes to test-runner.sh..."
    # Apply the fixes (this would need the actual patch content)
    echo "❌ Manual application required - see SECURITY_FIXES.md for detailed instructions"
fi

if ! grep -q "DEBUG:" "$SCRIPT_DIR/suites/security/security-scan.sh"; then
    echo "✅ Debug statements already removed from security-scan.sh"
else
    echo "🔧 Removing debug statements from security-scan.sh..."
    # Remove DEBUG statements
    sed -i.bak '/echo "DEBUG:/d' "$SCRIPT_DIR/suites/security/security-scan.sh"
    echo "✅ Debug statements removed"
fi

echo ""
echo "🧪 Testing fixes..."
if ./test-runner.sh security > /dev/null 2>&1; then
    echo "✅ Security tests pass"
else
    echo "❌ Security tests still failing"
fi

if ./test-runner.sh all > /dev/null 2>&1; then
    echo "✅ All tests pass"
    echo ""
    echo "🎉 Security fixes successfully applied!"
else
    echo "❌ Some tests still failing"
    echo ""
    echo "📋 Next steps:"
    echo "1. Check SECURITY_FIXES.md for detailed instructions"
    echo "2. Manually apply the remaining fixes"
    echo "3. Run './test-runner.sh all' to verify"
fi