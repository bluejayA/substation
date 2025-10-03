# syntax = docker/dockerfile:1
# This Dockerfile uses multi-stage build to customize DEV and PROD images:
# https://docs.docker.com/develop/develop-images/multistage-build/

# ================================
# Build image
# ================================
FROM swift:6.1 as build

# Set up a build area
WORKDIR /build

# First just resolve dependencies.
# This creates a cached layer that can be reused
# as long as your Package.swift/Package.resolved
# files do not change.
COPY ./Package.* ./

RUN swift package resolve

# Copy entire repo into container
COPY . .

# Build everything, with optimizations
RUN swift build -c release --static-swift-stdlib

# Copy main executable to staging area
RUN cp "$(swift build --package-path /build -c release --show-bin-path)/substation" /

# ================================
# Run image
# ================================
FROM swift:6.1-slim
LABEL maintainer="Cloudnull"
LABEL vendor="Cloudnull"
LABEL org.opencontainers.image.name="substation"
LABEL org.opencontainers.image.description="Substation, the OpenStack Terminal UI for Developers and Operators"
COPY --from=build /substation /substation
COPY --from=build /lib/x86_64-linux-gnu/libncurses.so.6 /lib/x86_64-linux-gnu/libncurses.so.6
ENV TERM=xterm
ENTRYPOINT [ "/substation" ]
