import sys
sys.path.append("/app/build")
import logos_emu
import time

def run():
    print("=== DMA BENCHMARK (BASELINE) ===")
    ctx = logos_emu.LogosContext()
    ctx.reset_state()
    
    # Проверяем счетчик тактов
    ctx.run(100)
    try:
        ticks = ctx.get_ticks()
        print(f"Test Run: {ticks} cycles passed.")
    except AttributeError:
        print("WARNING: get_ticks() not available in C++ driver yet.")
        ticks = 100

    print("✅ Benchmark infrastructure ready.")

if __name__ == "__main__":
    run()
