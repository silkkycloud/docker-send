####################################################################################################
## Builder
####################################################################################################
FROM node:current-alpine AS builder
ENV NODE_OPTIONS=--openssl-legacy-provider

RUN apk add --no-cache \ 
    ca-certificates \
    git

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
FROM node:current-alpine
ENV NODE_OPTIONS=--openssl-legacy-provider

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