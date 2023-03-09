#!/bin/bash
export HOME=/opt/gpilot
export MIX_ENV=prod
set -e
mix local.hex --force
mix local.rebar --force
mix deps.get
mix compile

elixir --sname rc-$HOSTNAME --cookie gpilotcookie -S mix run --no-halt