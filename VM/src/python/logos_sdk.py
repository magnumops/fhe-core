import os
import logos_emu

class TraceGuard:
    """
    Контекстный менеджер для 'Умной Трассировки'.
    Пишет VCD во временный файл.
    - При УСПЕХЕ: удаляет файл (чистота).
    - При ОШИБКЕ: переименовывает в ERROR_<name>.vcd (артефакт для отладки).
    """
    def __init__(self, emu, test_name):
        self.emu = emu
        self.name = test_name
        self.tmp_file = f"trace_{test_name}.tmp.vcd"
        self.final_file = f"ERROR_{test_name}.vcd"

    def __enter__(self):
        # Удаляем старые артефакты
        if os.path.exists(self.tmp_file): os.remove(self.tmp_file)
        if os.path.exists(self.final_file): os.remove(self.final_file)
        
        print(f"[TRACE-GUARD] Recording -> {self.tmp_file}")
        self.emu.start_trace(self.tmp_file)
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.emu.stop_trace()
        
        if exc_type:
            print(f"\n[TRACE-GUARD] 🚨 EXCEPTION DETECTED! Saving crash dump -> {self.final_file}")
            if os.path.exists(self.tmp_file):
                os.rename(self.tmp_file, self.final_file)
        else:
            print(f"[TRACE-GUARD] ✅ Success. Discarding trace.")
            if os.path.exists(self.tmp_file):
                os.remove(self.tmp_file)
        # Не подавляем исключение, пусть летит дальше
        return False
