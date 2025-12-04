FROM ubuntu:22.04

# Отключаем интерактивные вопросы при установке
ENV DEBIAN_FRONTEND=noninteractive

# Обновляем пакеты и устанавливаем базовые инструменты
# build-essential: gcc, g++, make
# cmake: для сборки
# verilator: наш RTL симулятор
# python3-dev: заголовочные файлы для PyBind11
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    python3 \
    python3-dev \
    python3-pip \
    verilator \
    && rm -rf /var/lib/apt/lists/*

# Устанавливаем PyBind11 через pip (обычно свежее, чем в apt)
RUN pip3 install pybind11

# Настраиваем рабочую директорию
WORKDIR /app

# Копируем исходный код (пока только структуру)
COPY . /app

# Проверка версий (для логов сборки)
RUN verilator --version && python3 --version && cmake --version
