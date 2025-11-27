#!/usr/bin/env bash

cat > event.json <<'EOF'
{
  "ref": "refs/heads/fix-1.1.0-snapshot-build",
  "inputs": {
    "version": "1.1.0",
    "snapshot": "true",
    "distribution": "[\"run\"]",
    "platform": "[\"amd64\"]"

  }
}
EOF

act --container-architecture linux/amd64 \
  -W .github/workflows/build-test-and-publish.yml \
  -e event.json \
  workflow_dispatch

