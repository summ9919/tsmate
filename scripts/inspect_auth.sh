#!/usr/bin/env bash
cd tsmate || exit 1
U=$(git config --get remote.origin.url)
echo "$U" | sed -E "s#(https://[^:{{PASSWORD_8evx49vz}}@]+@#\1:****@#"
case "$U" in
  *://*@*)
    echo has-cred
    C=$(echo "$U" | sed -E "s#^https://([^@]+)@.*#\1#")
    echo credlen=${#C}
    case "$C" in
      *:*) echo user-colon-pass ;;
      *) echo token-only ;;
    esac ;;
  *) echo no-cred ;;
esac
echo "--- gh config"
ls -1 ~/.config/gh 2>/dev/null || echo none
