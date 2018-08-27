FROM        node:8
MAINTAINER  Apiary <sre@apiary.io>

RUN mkdir -p app

COPY . /app

WORKDIR "/app"

RUN npm install
