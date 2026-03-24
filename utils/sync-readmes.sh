#!/usr/bin/env bash
#
# Copies README files listed in readme-paths.txt into the project root.
# Each line should be: <source_path> <output_filename>
# Overwrites existing files in the project root.
#
# Usage: ./utils/sync-readmes.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PATHS_FILE="$SCRIPT_DIR/readme-paths.txt"

if [ ! -f "$PATHS_FILE" ]; then
    echo "Error: $PATHS_FILE not found."
    echo "Create it with one entry per line: <source_path> <output_filename>"
    echo "  /home/user/projects/Dogcraft-Chat/README.md Dogcraft-Chat.md"
    echo "  /home/user/projects/Dogcraft-Economy/README.md Dogcraft-Economy.md"
    exit 1
fi

copied=0
skipped=0

while IFS= read -r line || [ -n "$line" ]; do
    # Strip carriage returns (Windows line endings)
    line="${line%$'\r'}"

    # Skip blank lines and comments
    [[ -z "$line" || "$line" == \#* ]] && continue

    # Last token is the output filename, everything before it is the source path
    output="${line##* }"
    src="${line% *}"

    if [ -z "$src" ] || [ -z "$output" ] || [ "$src" = "$output" ]; then
        echo "SKIP: bad format -> $line"
        echo "      Expected: <source_path> <output_filename>"
        ((skipped++))
        continue
    fi

    if [ ! -f "$src" ]; then
        echo "SKIP: $src (file not found)"
        ((skipped++))
        continue
    fi

    cp "$src" "$PROJECT_DIR/$output"
    echo "  OK: $output <- $src"
    ((copied++))
done < "$PATHS_FILE"

echo ""
echo "Done. Copied $copied file(s), skipped $skipped."
