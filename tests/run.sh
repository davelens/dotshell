#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

bash -n setup/init.sh setup/uninstall.sh setup/lib/platform.sh setup/platforms/*.sh \
  bin/dshell bin/generate-gtk-css modules/ai-agents-monitor/bin/remote-stream \
  tests/run.sh tests/setup_test.sh tests/remote_stream_test.sh

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required to validate JSON files" >&2
  exit 1
fi

while IFS= read -r -d '' json_file; do
  jq empty "$json_file"
done < <(find core modules statusbar themes -name '*.json' -type f -print0)

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck setup/init.sh setup/uninstall.sh setup/dotshell.run setup/lib/platform.sh \
    setup/platforms/*.sh modules/ai-agents-monitor/bin/remote-stream \
    tests/run.sh tests/setup_test.sh tests/remote_stream_test.sh
fi

bash tests/remote_stream_test.sh
bash tests/setup_test.sh
