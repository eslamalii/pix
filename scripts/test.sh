#!/bin/sh
# Runs the test suite. The explicit plugin path works around the command line tools
# intermittently failing to find the Swift Testing macro plugin ("plugin for module
# 'TestingMacros' not found").
set -e
cd "$(dirname "$0")/.."
PLUGINS="$(dirname "$(xcrun --find swift)")/../lib/swift/host/plugins/testing"
exec swift test -Xswiftc -plugin-path -Xswiftc "$PLUGINS" "$@"
