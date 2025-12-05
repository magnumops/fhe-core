import logos_emu

class TaskScheduler:
    def __init__(self):
        self.ctx = logos_emu.LogosContext()
        self.queue = []
        self.next_core = 0 # Round-Robin counter

    def add_ntt_task(self, slot_id):
        """Добавляет задачу в очередь, автоматически выбирая ядро."""
        assigned_core = self.next_core
        self.queue.append({
            'type': 'NTT',
            'core': assigned_core,
            'slot': slot_id
        })
        print(f"[SDK] Scheduled NTT -> Core {assigned_core} (Slot {slot_id})")
        
        # Переключаем на следующее ядро (0 -> 1 -> 0)
        self.next_core = 1 - self.next_core

    def add_dma_task(self):
        self.queue.append({'type': 'DMA'})
        print(f"[SDK] Scheduled DMA Transfer")

    def execute_batch(self):
        """Отправляет всю очередь в железо и ждет завершения."""
        if not self.queue:
            return

        print(f"[SDK] Committing batch of {len(self.queue)} tasks...")
        
        # 1. Сброс перед новой пачкой
        self.ctx.reset_state()
        
        # 2. Отправка команд
        for task in self.queue:
            if task['type'] == 'NTT':
                self.ctx.push_ntt_op(task['core'], task['slot'])
            elif task['type'] == 'DMA':
                self.ctx.push_dma()
        
        # 3. Сигнал остановки (когда все закончат)
        self.ctx.push_halt()
        
        # 4. Запуск симуляции
        self.ctx.run()
        
        # 5. Очистка очереди
        self.queue = []
        print("[SDK] Batch execution finished.")

    def get_stats(self):
        return {
            0: self.ctx.get_core_ops(0),
            1: self.ctx.get_core_ops(1)
        }
