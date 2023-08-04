# Build AWS CLI V2 for linux alpine
# See https://stackoverflow.com/questions/60298619/awscli-version-2-on-alpine-linux
# See https://github.com/aws/aws-cli/issues/4685
ARG ALPINE_VERSION=3.16
FROM python:3.10.5-alpine${ALPINE_VERSION} as builder

ARG AWS_CLI_VERSION=2.7.20
RUN apk add --no-cache git unzip groff build-base libffi-dev cmake
RUN git clone --single-branch --depth 1 -b ${AWS_CLI_VERSION} https://github.com/aws/aws-cli.git

WORKDIR aws-cli
RUN sed -i'' 's/PyInstaller.*/PyInstaller==5.2/g' requirements-build.txt
RUN python -m venv venv
RUN . venv/bin/activate
RUN scripts/installers/make-exe
RUN unzip -q dist/awscli-exe.zip
RUN aws/install --bin-dir /aws-cli-bin
RUN /aws-cli-bin/aws --version

# reduce image size: remove autocomplete and examples
RUN rm -rf /usr/local/aws-cli/v2/current/dist/aws_completer /usr/local/aws-cli/v2/current/dist/awscli/data/ac.index /usr/local/aws-cli/v2/current/dist/awscli/examples
RUN find /usr/local/aws-cli/v2/current/dist/awscli/botocore/data -name examples-1.json -delete

# Build final docker image now that all binaries are OK
FROM node:16-alpine as base

ARG UPLIFT_VERSION
ENV UPLIFT_VERSION $UPLIFT_VERSION

# Entrypoint file
ENV DOCKER_DRIVER overlay
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Install alpine packages
RUN apk update
RUN apk upgrade --available
RUN apk add --no-cache curl wget zip tar git openssl openssh-client jq
RUN apk add --no-cache bash tar gzip yarn
RUN rm -rf /var/cache/apk/*

# Install node tools
RUN npm i -g pino pino-pretty

# Install uplift
COPY files/uplift.tar.gz /root/uplift.tar.gz
RUN mkdir -p /root/uplift_temp
RUN tar -xvzf /root/uplift.tar.gz C /root/uplift_temp
RUN rm /root/uplift.tar.gz
RUN mv /root/uplift_temp/uplift /usr/local/bin/uplift
RUN rm -Rf /root/uplift_temp
RUN chmod +x /usr/local/bin/uplift
RUN uplift -v

# Install AWS CLI V2
COPY --from=builder /usr/local/aws-cli/ /usr/local/aws-cli/
COPY --from=builder /aws-cli-bin/ /usr/local/bin/
RUN aws --version

# Entrypoint
ENTRYPOINT ["/bin/bash", "-l", "-c"]

# Test the image before building
FROM base AS test

RUN node -v && \
    npm -v && \
    yarn -v && \
    aws --version

# Create Image after tests
FROM base AS release
