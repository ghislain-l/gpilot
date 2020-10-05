#!/bin/bash
export HOME=/opt/gpilot
export MIX_ENV=prod
set -e
mix local.hex
mix local.rebar
mix deps.get
mix compile

ln -s /opt/gpilot/gpilot.service /etc/systemd/system/gpilot.service
systemctl daemon-reload
systemctl enable gpilot.service
systemctl start gpilot.service
