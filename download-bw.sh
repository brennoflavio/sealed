set -euo pipefail

BW_ARTIFACT_URL='https://git.brennoflavio.com.br/brennoflavio/sealed/actions/runs/200/artifacts/bw-linux-arm64-2026.7.0'
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

cd "$(dirname "$0")"

curl -fsSL "$BW_ARTIFACT_URL" -o "$temp_dir/artifact.zip"
unzip -p "$temp_dir/artifact.zip" bw > "$temp_dir/bw"
unzip -p "$temp_dir/artifact.zip" bw.sha256 > "$temp_dir/bw.sha256"
(
    cd "$temp_dir"
    sha256sum -c bw.sha256
)

mkdir -p lib
install -m 755 "$temp_dir/bw" lib/bw
