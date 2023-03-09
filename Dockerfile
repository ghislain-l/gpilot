FROM elixir:1.9-slim

EXPOSE 8080

COPY . /opt/gpilot
WORKDIR /opt/gpilot
ENTRYPOINT ["sh","docker-entrypoint.sh"]


