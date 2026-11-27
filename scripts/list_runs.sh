#!/usr/bin/env bash
cd tsmate || exit 1
CRED=$(git config --get remote.origin.url | sed -E "s#^https://([^@]+)@.*#\1#")
TOK=${CRED#*:}
echo "tok_len=${#TOK}"
curl -s -o /dev/null -w "user_http=%{http_code}\n" -H "Authorization: token $TOK" https://api.github.com/user
GH_TOKEN=$TOK gh run list --repo summ9919/tsmate --limit 5 2>&1 | head -10
