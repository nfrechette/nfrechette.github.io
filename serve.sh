#!/bin/sh
# Starts a local preview at http://localhost:4000. Use "./serve.sh build" for a one-off build into _site/.
# Extra arguments go to jekyll, for example "./serve.sh build -d /tmp/site".

# The rbenv shims select the Ruby in .ruby-version, also in a shell that did not run "rbenv init".
if [ -d "$HOME/.rbenv/shims" ]; then
  PATH="$HOME/.rbenv/shims:$PATH"
fi

# Sass fails on non-ASCII characters without a UTF-8 locale.
export LANG=en_US.UTF-8

command="${1:-serve}"
if [ $# -gt 0 ]; then
  shift
fi

exec bundle exec jekyll "$command" --future "$@"
