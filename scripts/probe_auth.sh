#!/usr/bin/env bash
cd tsmate || exit 1
CRED=$(git config --get remote.origin.url | sed -E "s#^https://([^@]+)@.*#\1#")
echo "credlen=${#CRED}"
case "$CRED" in
  *:*) echo shape=user-colon-token ;;
  *) echo shape=token-only ;;
esac
USERPART=${CRED%%:*}
PASSWORD_dummy=1
TOK=${CRED#*:}
echo "userpart_len=${#USERPART} tok_len=${#TOK}"
echo -n "userpart_is_summ9919: "; [ "$USERPART" = "summ9919" ] && echo yes || echo no
code() { curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $1" https://api.github.com/user; }
echo "auth_with_passpart=$(code "$TOK")"
echo "auth_with_whole=$(code "$CRED")"
echo "--- ssh remote test"
GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=no" git ls-remote origin 2>&1 | head -3
