#!/bin/bash

# Remove all console.log, console.error, console.warn, console.debug statements
echo "Removing console statements from TypeScript/TSX files..."

# Count before
BEFORE=$(grep -r "console\." --include="*.tsx" --include="*.ts" --exclude-dir=node_modules --exclude-dir=.next src/ | wc -l)
echo "Found $BEFORE console statements before cleanup"

# Remove console statements
find src/ -type f \( -name "*.tsx" -o -name "*.ts" \) -exec sed -i '/console\./d' {} \;

# Count after
AFTER=$(grep -r "console\." --include="*.tsx" --include="*.ts" --exclude-dir=node_modules --exclude-dir=.next src/ | wc -l)
echo "Found $AFTER console statements after cleanup"

echo "Removed $((BEFORE - AFTER)) console statements"