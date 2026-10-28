#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/swift-tool.sh test
