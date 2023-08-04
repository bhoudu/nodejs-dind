# Build final docker image now that all binaries are OK
FROM docker:24 as base

ARG NODE_VERSION
ENV NODE_VERSION $NODE_VERSION
ARG FULL_NODE_VERSION
ENV FULL_NODE_VERSION $FULL_NODE_VERSION
ARG UPLIFT_VERSION
ENV UPLIFT_VERSION $UPLIFT_VERSION

# Install alpine packages
RUN apk update
RUN apk upgrade --available
RUN apk add --no-cache aws-cli docker-compose curl wget zip tar git openssl openssh-client jq bash tar gzip openrc libstdc++
RUN rm -rf /var/cache/apk/*

# Test AWSCLI
RUN aws --version

# Test docker-compose
RUN docker-compose -v

# Install nodejs for musl linux
COPY files/node-linux-x64-musl.tar.gz /root/node-linux-x64-musl.tar.gz
RUN tar -xzf /root/node-linux-x64-musl.tar.gz -C /root
RUN rm /root/node-linux-x64-musl.tar.gz
ENV PATH="/root/node-${FULL_NODE_VERSION}-linux-x64-musl/bin:${PATH}"
RUN echo "export PATH=$PATH" > /etc/environment
RUN node -v

# Install node tools
RUN npm install --global yarn
RUN yarn -v

# Install node deps
RUN npm i -g pino pino-pretty

# Install uplift
COPY files/uplift.tar.gz /root/uplift.tar.gz
RUN mkdir -p /root/uplift_temp
RUN tar -xvzf /root/uplift.tar.gz -C /root/uplift_temp
RUN rm /root/uplift.tar.gz
RUN mv /root/uplift_temp/uplift /usr/local/bin/uplift
RUN rm -Rf /root/uplift_temp
RUN chmod +x /usr/local/bin/uplift
RUN uplift -v

# Entrypoint
ENTRYPOINT ["/bin/bash", "-l", "-c"]

# Test the image before building
FROM base AS test

RUN node -v && \
    npm -v && \
    yarn -v && \
    uplift version && \
    aws --version

# Create Image after tests
FROM base AS release
