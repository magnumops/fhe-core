FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    python3 \
    python3-dev \
    python3-pip \
    verilator \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install pybind11

WORKDIR /app
COPY . /app

# Чистая сборка
RUN rm -rf build && mkdir -p build && cd build && cmake .. && make

# Финальный тест
RUN python3 tests/test_day4_integration.py
