#!/usr/bin/env bash
# Inbound VIP call to Twilio DID → SIPp catcher ext 2000.
# Start catcher first: ./run-catcher.sh uas
exec "$(cd "$(dirname "$0")" && pwd)/run-sipp.sh" in-open-ext catcher "$@"
