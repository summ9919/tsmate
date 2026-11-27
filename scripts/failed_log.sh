#!/usr/bin/env bash
cd tsmate || exit 1
CRED=$(git config --get remote.origin.url | sed -E "s#^https://([^@]+)@.*#\1#")
TOK=${CRED#*:}
GH_TOKEN=$TOK gh run view 45947543942 --repo summ9919/tsmate --log-failed 2>&1 | grep -E "error:|warning: .*unused|BUILD FAILED|The following build commands failed" | head -40
