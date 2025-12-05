import sys
# Добавляем путь к python исходникам
sys.path.append("/app/src/python")
sys.path.append("/app/build")

from logos_scheduler import TaskScheduler

def test_scheduler():
    print("--- Starting Day 9: Scheduler Automation Test ---")
    
    sched = TaskScheduler()
    
    # Сценарий: Мы хотим обработать 6 полиномов.
    # Планировщик должен сам раскидать их: 3 на Core0, 3 на Core1.
    print("[1] Scheduling 6 tasks...")
    for i in range(6):
        sched.add_ntt_task(slot_id=i)
        
    # Добавим DMA трансфер посередине (эмуляция загрузки данных)
    sched.add_dma_task()
    
    print("[2] Executing Batch...")
    sched.execute_batch()
    
    # Проверка
    stats = sched.get_stats()
    print(f"[3] Stats: {stats}")
    
    # Ожидаем по 3 операции на ядро (DMA не считается в ops ядер)
    if stats[0] == 3 and stats[1] == 3:
        print("✅ SUCCESS: Automatic Load Balancing works!")
    else:
        print(f"❌ FAIL: Expected {3} ops each, got {stats}")
        sys.exit(1)

if __name__ == "__main__":
    test_scheduler()
