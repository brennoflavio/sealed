set -euo pipefail

cd "$INSTALL_DIR"

VENV_PATH="$BUILD_DIR/venv"
export UV_PROJECT_ENVIRONMENT="$VENV_PATH"

/usr/local/uv sync

cp -r "$VENV_PATH"/lib/python*/site-packages/* .
