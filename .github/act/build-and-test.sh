#!/usr/bin/env bash

# Allow branch ref to be set via environment variable or argument, default to "refs/heads/main"
BRANCH_REF="${1:-${BRANCH_REF:-refs/heads/main}}"

cat > event.json <<EOF
{
  "ref": "${BRANCH_REF}",
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
