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

# Сборка
RUN mkdir -p build && cd build && cmake .. && make

# Тесты
# 1. PyBind тест (День 2)
RUN python3 tests/test_day2.py

# 2. Verilator тест (День 3)
# Запускаем скомпилированный бинарник
RUN ./build/verilator_test
