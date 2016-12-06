FROM        apiaryio/nodejs:4
MAINTAINER  Apiary <sre@apiary.io>

RUN mkdir -p app

COPY . /app

WORKDIR "/app"

CMD npm install
