FROM ubuntu:24.04
RUN apt-get update && apt-get install -y build-essential cmake git python3 python3-dev python3-pip verilator ccache libgmp-dev && rm -rf /var/lib/apt/lists/*
RUN pip3 install --break-system-packages pybind11 numpy pytest
WORKDIR /tmp
RUN git clone https://github.com/microsoft/SEAL.git && cd SEAL && cmake -S . -B build -DSEAL_USE_MSGSL=OFF -DSEAL_USE_ZLIB=OFF -DSEAL_USE_ZSTD=OFF && cmake --build build -j$(nproc) && cmake --install build && cd .. && rm -rf SEAL
WORKDIR /app
COPY . /app
RUN mkdir -p verilator_out
RUN verilator --cc --exe --Mdir verilator_out --CFLAGS "-fPIC" -Wno-fatal -y src/rtl/ntt -y src/rtl --top-module logos_core src/rtl/logos_core.v src/rtl/command_processor.v src/rtl/mem_arbiter.v src/rtl/dpi_mem_wrapper.v src/rtl/dma_unit.v src/rtl/ntt/ntt_core.v src/rtl/ntt/ntt_engine.v src/rtl/ntt/ntt_control.v src/rtl/ntt/butterfly.v src/rtl/ntt/mod_mult.v src/rtl/ntt/mod_add.v src/rtl/ntt/mod_sub.v src/rtl/ntt/vec_alu.v
RUN rm -rf build && mkdir -p build && cd build && cmake .. && make -j$(nproc)
ENV PYTHONPATH="${PYTHONPATH}:/app/build"
CMD ["/bin/bash"]
