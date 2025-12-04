FROM ubuntu:22.04

# 1. Install Dependencies
# Update apt and install essential tools
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    python3 \
    python3-pip \
    python3-dev \
    verilator \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Python Deps
RUN pip3 install pybind11 numpy

# 3. Setup Workspace
WORKDIR /tmp

# 4. Install Microsoft SEAL (Cached Layer)
# We compile it once to save time
RUN git clone https://github.com/microsoft/SEAL.git && \
    cd SEAL && \
    git checkout v4.1.1 && \
    cmake -S . -B build -DSEAL_USE_MSGSL=OFF -DSEAL_USE_ZLIB=OFF -DSEAL_BUILD_EXAMPLES=OFF -DSEAL_BUILD_TESTS=OFF && \
    cmake --build build && \
    cmake --install build

# 5. Application Layer
WORKDIR /app
COPY . /app

# 6. Build Project
# Clean build to ensure no artifacts
RUN rm -rf build && mkdir -p build && cd build && cmake .. && make

# 7. Environment
ENV PYTHONPATH="/app/build:/app/src/python:${PYTHONPATH}"

# 8. Run Verification Test (Phase 2 Day 7)
RUN python3 tests/test_day9_intt.py
