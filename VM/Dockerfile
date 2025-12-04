FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y build-essential cmake git python3 python3-dev python3-pip verilator && rm -rf /var/lib/apt/lists/*
RUN pip3 install pybind11
WORKDIR /tmp
RUN git clone https://github.com/microsoft/SEAL.git && cd SEAL && git checkout v4.1.1 && cmake -S . -B build -DSEAL_USE_MSGSL=OFF -DSEAL_USE_ZLIB=OFF -DSEAL_BUILD_TESTS=OFF && cmake --build build -j$(nproc) && cmake --install build && cd .. && rm -rf SEAL
WORKDIR /app
COPY . /app
RUN rm -rf build && mkdir -p build && cd build && cmake .. && make
# Исправленный ENV
ENV PYTHONPATH="/app/build:/app/src/python:${PYTHONPATH}"
RUN python3 tests/test_day10_final.py
