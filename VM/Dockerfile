FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Установка инструментов
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

# --- ЭТАП СБОРКИ (ДЕНЬ 2) ---
# 1. Создаем папку build
# 2. Запускаем CMake
# 3. Компилируем (make)
RUN mkdir build && cd build && cmake .. && make

# --- ЭТАП ТЕСТИРОВАНИЯ ---
# Запускаем тест прямо при сборке. Если тест упадет, сборка упадет.
RUN python3 tests/test_day2.py
