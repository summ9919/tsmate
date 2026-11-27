#!/usr/bin/env bash
cd tsmate || exit 1
TOK=$(git config --get remote.origin.url | sed -E "s#^https://[^:@]+@.*#\1#")
echo "len=${#TOK}"
curl -s -o /dev/null -w "user_http=%{http_code}\n" -H "Authorization: token $TOK" https://api.github.com/user
GH_TOKEN=$TOK gh run list --repo summ9919/tsmate --limit 4 2>&1 | head -12
