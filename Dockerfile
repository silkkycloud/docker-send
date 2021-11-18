####################################################################################################
## Builder
####################################################################################################
FROM node:current-alpine3.14 AS builder
ENV NODE_OPTIONS=--openssl-legacy-provider

RUN apk add --no-cache git

WORKDIR /send

RUN git clone https://gitlab.com/timvisee/send.git /send

RUN set -x \
    # Build
    && PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true npm ci \
    && npm run build

####################################################################################################
## Final image
####################################################################################################
FROM node:current-alpine3.14
ENV NODE_OPTIONS=--openssl-legacy-provider

RUN apk add --no-cache git

WORKDIR /send

# Create directory structure
RUN mkdir -p ./app \
    && mkdir -p ./common \
    && mkdir -p ./public/locales \
    && mkdir -p ./server

RUN git clone https://gitlab.com/timvisee/send.git /tmp/send \
    && cp -r /tmp/send/package.json ./ \
    && cp -r /tmp/send/package-lock.json ./ \
    && cp -r /tmp/send/app ./app \
    && cp -r /tmp/send/common ./common \
    && cp -r /tmp/send/public/locales ./public/locales \
    && cp -r /tmp/send/server ./server \
    && rm -rf /tmp/send

COPY --from=builder /send/dist ./dist

RUN npm ci --production \
    && npm cache clean --force
RUN mkdir -p /send/.config/configstore
RUN ln -s dist/version.json version.json

# Add non root user
RUN adduser --disabled-password --gecos "" --no-create-home send
RUN chown -R send:send /send

USER send

ENV PORT=8080

EXPOSE 8080

CMD ["node", "./server/bin/prod.js"]

STOPSIGNAL SIGTERM

HEALTHCHECK \
    --start-period=30s \
    --interval=1m \
    --timeout=3s \
    CMD wget --spider --q http://localhost:8080/ || exit 1