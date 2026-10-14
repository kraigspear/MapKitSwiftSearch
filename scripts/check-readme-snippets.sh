#!/bin/bash
# Compiles every ```swift block in README.md against this package, so a README
# example that no longer builds fails CI instead of reaching a reader.
#
# Each block becomes its own target in a scratch package that depends on the
# repo by path, so snippets can't collide with each other. A block that runs
# statements is wrapped in a @MainActor async function, which allows top-level
# `await` and `try`. Package.swift fragments are skipped: they aren't Swift that
# compiles on its own. #sourceLocation maps compiler errors back to README lines.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
readme="$repo_root/README.md"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# Later snippets use names the README introduced earlier, as prose does. Each
# wrapper function receives them as parameters; a snippet that declares its
# own shadows the parameter.
ambient_parameters="locationSearch: LocationSearch, completion: LocalSearchCompletion"

# Split the README into blocks/N.swift, with the README line of each block's
# first line in blocks/N.line.
mkdir -p "$scratch/blocks"
block_count="$(awk -v dir="$scratch/blocks" '
    /^```swift[[:space:]]*$/ { n++; file = dir "/" n ".swift"; print NR + 1 > (dir "/" n ".line"); printf "" > file; inside = 1; next }
    inside && /^```[[:space:]]*$/ { inside = 0; close(file); next }
    inside { print > file }
    END { print n + 0 }
' "$readme")"

# A manifest fragment starts with an argument label (`dependencies:`) or a
# leading-dot member (`.target(`).
is_manifest_fragment() {
    grep -qE '^import PackageDescription' "$1" && return 0
    awk 'NF { print; exit }' "$1" | grep -qE '^[[:space:]]*([A-Za-z]+:|\.)'
}

# Column-0 lines are top-level code. Anything other than an import, attribute,
# comment, closing bracket, or declaration is a statement that needs wrapping.
has_top_level_statements() {
    grep -E '^[^[:space:]]' "$1" \
        | grep -vE '^(import |@|//|[]})])' \
        | grep -qvE '^((public|internal|fileprivate|private|final|nonisolated) )*(struct|class|enum|actor|protocol|extension|func|typealias) '
}

targets=""
built=0
skipped=0
for ((n = 1; n <= block_count; n++)); do
    block="$scratch/blocks/$n.swift"
    line="$(cat "$scratch/blocks/$n.line")"
    if is_manifest_fragment "$block"; then
        echo "Skipping README.md:$line (Package.swift fragment)"
        skipped=$((skipped + 1))
        continue
    fi

    target="Snippet$n"
    source="$scratch/Sources/$target/$target.swift"
    mkdir -p "$(dirname "$source")"
    {
        echo "import MapKitSwiftSearch"
        if has_top_level_statements "$block"; then
            # Imports must stay at file scope, outside the wrapper.
            grep -E '^import ' "$block" || true
            echo "@MainActor func snippet$n($ambient_parameters) async throws {"
            echo "#sourceLocation(file: \"$readme\", line: $line)"
            sed -E 's/^import .*//' "$block"
            echo "#sourceLocation()"
            echo "}"
        else
            echo "#sourceLocation(file: \"$readme\", line: $line)"
            cat "$block"
        fi
    } > "$source"

    targets="$targets
        .target(name: \"$target\", dependencies: [.product(name: \"MapKitSwiftSearch\", package: \"$(basename "$repo_root")\")]),"
    built=$((built + 1))
done

if [ "$built" -eq 0 ]; then
    echo "error: no Swift snippets found in $readme" >&2
    exit 1
fi

cat > "$scratch/Package.swift" <<EOF
// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "ReadmeSnippets",
    platforms: [.iOS(.v26), .macOS(.v26)],
    dependencies: [.package(path: "$repo_root")],
    targets: [$targets
    ]
)
EOF

echo "Building $built README snippets ($skipped Package.swift fragments skipped)"
swift build --package-path "$scratch"
