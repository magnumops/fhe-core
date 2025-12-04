# Реестр Отвергнутых Гипотез и Ошибок (POSTMORTEM)

## Сессия: Фаза 1 (Integration Skeleton)
### Эпизод: Подключение Verilator к CMake в Docker

| ID | Гипотеза / Проблема | Предпринятое Действие | Результат | Анализ Провала (Root Cause) |
| :--- | :--- | :--- | :--- | :--- |
| PM-001 | `find_package(Verilator)` автоматически найдет пути в Ubuntu 22.04. | Использован стандартный `find_package`. | Ошибка CMake: переменные путей остались пустыми. | В пакете `verilator` для Ubuntu 22.04 отсутствуют корректные `.cmake` конфиги для автопоиска. |
| PM-002 | Verilator найдет исходники `.v`, если запустить его из папки `build`. | `COMMAND verilator ... src/rtl/counter.v` | Ошибка Verilator: `Cannot find file`. | Verilator (как и многие CLI утилиты) чувствителен к CWD. При запуске из `build` относительный путь `src/` неверен. Требуется абсолютный путь `${CMAKE_SOURCE_DIR}`. |
| PM-003 | Достаточно добавить основные `.cpp` файлы Verilator в `add_executable`. | Добавлены `Vcounter.cpp` и `Vcounter__Syms.cpp`. | Linker Error: `undefined reference to Vcounter::Vcounter`. | Линковщику не хватило файла `Vcounter__Slow.cpp`, где Verilator прячет конструкторы. |
| PM-004 | Если добавить все файлы в `add_executable`, CMake сам поймет, что их надо сгенерировать. | Добавлен `Vcounter__Slow.cpp` в цель сборки, но не в `OUTPUT` команды генерации. | CMake Error: `Cannot find source file`. | CMake проверяет наличие исходников *до* сборки. Если файл генерируемый, он ОБЯЗАН быть в списке `OUTPUT` той команды, которая его создает. |


## Успешное завершение Фазы 1
**Статус:** Скелет готов.
**Достижение:** Реализован класс `CounterSim` с методами `step()` и `reset()`. Python-тест прошел валидацию. Риски интеграции языков и инструментов устранены.
