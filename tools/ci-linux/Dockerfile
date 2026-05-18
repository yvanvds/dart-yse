# Local Linux validation for dart-yse on a Windows dev box.
#
# Builds libyse.so against system PortAudio / libsndfile / RtMidi and runs
# `dart analyze` + a load-smoke against the resulting .so. Mirrors the
# upstream yse-soundengine `tools/ci-linux/Dockerfile` and adds the Dart SDK.
#
# Usage from PowerShell at the dart-yse repo root:
#   docker build -t dart-yse-ci -f tools/ci-linux/Dockerfile .
#   docker run --rm -v ${PWD}:/workspace dart-yse-ci
#
# The default command builds the engine into
# third_party/yse-soundengine/build-linux/ (separate from the Windows
# `build/` so the two toolchains never collide), then runs the Dart
# validation against it.

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Engine build deps — identical to upstream's tools/ci-linux/Dockerfile —
# plus the prerequisites for the Dart APT repo.
RUN apt-get update -y && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        ninja-build \
        pkg-config \
        portaudio19-dev \
        libsndfile1-dev \
        librtmidi-dev \
        ca-certificates \
        curl \
        gnupg \
        git \
        apt-transport-https \
    && rm -rf /var/lib/apt/lists/*

# Dart SDK (stable channel) — installed via the official Google APT repo
# so the version tracks upstream releases.
RUN curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub \
        | gpg --dearmor -o /usr/share/keyrings/dart.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main" \
        > /etc/apt/sources.list.d/dart_stable.list \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends dart \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Build the engine into a dart-yse-owned path (.docker-build/) rather than
# inside the submodule. The submodule may be a Windows junction to a separate
# engine-dev workspace that already has its own build-linux/ — keeping our
# artefacts out of there avoids stale-CMakeCache collisions on iterate.
CMD ["bash", "-c", "set -ex && \
    cmake -S third_party/yse-soundengine -B .docker-build/yse -G Ninja \
        -DCMAKE_BUILD_TYPE=Release && \
    cmake --build .docker-build/yse --target yse && \
    dart pub get && \
    dart analyze && \
    YSE_DLL_PATH=$(pwd)/.docker-build/yse/bin dart run tool/linux_smoke.dart"]
