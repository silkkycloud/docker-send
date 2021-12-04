####################################################################################################
## Builder
####################################################################################################
FROM node:16.13-alpine3.14 AS builder

RUN apk add --no-cache \ 
    ca-certificates \
    tar

WORKDIR /send

ADD https://gitlab.com/timvisee/send/-/archive/master/send-master.tar.gz /tmp/send-master.tar.gz
RUN tar xvfz /tmp/send-master.tar.gz -C /tmp \
    && cp -r /tmp/send-master/. /send

RUN set -x \
    # Build
    && PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true npm ci \
    && npm run build

####################################################################################################
## Final image
####################################################################################################
FROM node:16.13-alpine3.14

ENV PORT=8080

RUN apk add --no-cache \ 
    ca-certificates \
    git \
    tini

WORKDIR /send

# Add an unprivileged user and set directory permissions
RUN adduser --disabled-password --gecos "" --no-create-home send \
    && chown -R send:send /send

COPY --from=builder --chown=send:send /send/package*.json ./
COPY --from=builder --chown=send:send /send/app app
COPY --from=builder --chown=send:send /send/common common
COPY --from=builder --chown=send:send /send/public/locales public/locales
COPY --from=builder --chown=send:send /send/server server
COPY --from=builder --chown=send:send /send/dist dist

RUN npm ci --production \
    && npm cache clean --force
RUN mkdir -p /send/.config/configstore
RUN ln -s dist/version.json version.json

ENTRYPOINT ["/sbin/tini", "--"]

USER send

CMD ["node", "./server/bin/prod.js"]

EXPOSE 8080

STOPSIGNAL SIGTERM

HEALTHCHECK \
    --start-period=30s \
    --interval=1m \
    --timeout=3s \
    CMD wget --spider --q http://localhost:8080/ || exit 1

# Image metadata
LABEL org.opencontainers.image.title=Send
LABEL org.opencontainers.image.description="Simple, private file sharing. Send lets you share files with end-to-end encryption and a link that automatically expires. So you can keep what you share private and make sure your stuff doesn’t stay online forever."
LABEL org.opencontainers.image.url=https://send.silkky.cloud
LABEL org.opencontainers.image.vendor="Silkky.Cloud"
LABEL org.opencontainers.image.licenses=Unlicense
LABEL org.opencontainers.image.source="https://github.com/silkkycloud/docker-send"