#!/bin/bash
# Backward compatibility wrapper - redirects to new location
# This maintains existing documentation and user workflows

echo "🔄 Redirecting to organized script location..."
echo "💡 New location: ./deployment/deploy-local.sh"
echo ""

# Execute the actual script
exec "$(dirname "${BASH_SOURCE[0]}")/deployment/deploy-local.sh" "$@"