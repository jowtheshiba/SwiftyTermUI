# SwiftyTermUI - План розробки

## Огляд проекту

SwiftyTermUI - це нативна реалізація TUI (Terminal User Interface) бібліотеки для Swift, вдохновлена ncurses. На відміну від обгортки над ncurses, це повна переробка з нуля з використанням ANSI escape sequences та прямої роботи з терміналом.

## Основні можливості ncurses (базис для розробки)

### 1. Управління екраном та вікнами
- **stdscr** - стандартний екран (весь термінал)
- **Windows** - віртуальні окна (перекриття, стеки, незалежне управління)
- **Координати** - y,x формат (рядок, колона)
- **Refresh** - оптимізоване оновлення тільки змінених ділянок

### 2. Курсор та позиціонування
- `move(y, x)` - переміщення курсора
- `getyx()` / `getmaxyx()` - отримання позиції та розмірів
- Відслідковування змін для оптимізації рендеру

### 3. Вивід та форматування
- `printw()`, `mvprintw()`, `addstr()` - висновок тексту
- **Атрибути** - bold, italic, underline, blink, reverse, dim
- **Кольори** - пари foreground/background з підтримкою 8-256 кольорів
- Попередження про вихід за межі вікна

### 4. Введення
- `getch()` - одиничний символ без очікування Enter
- `wgetch(win)` - введення для конкретного вікна
- Необхідність обробки всіх спеціальних клавіш (стрілки, F1-F12 тощо)

### 5. Рендеринг та перформанс
- Буферизація - весь контент спочатку в буфері, потім вивід на екран
- Мінімізація escape sequences - тільки необхідні команди
- Відстеження "бруду" (dirty cells) - яких символів змінилось

### 6. ANSI control sequences
```
\033[2J       - очистити екран
\033[H        - переместить курсор на (0,0)
\033[y;xH     - переместить курсор на (y,x)
\033[m        - скинути атрибути
\033[1m       - bold
\033[4m       - underline
\033[38;5;Nm  - foreground color
\033[48;5;Nm  - background color
\033[?25h/l   - показати/приховати курсор
```

---

## Етапи розробки

### Етап 1: Фундамент (Foundation) ✅ COMPLETED
**Мета**: основна інфраструктура та управління терміналом

- [x] **1.1** - Структура проекту та Package.swift
  - Організація модулів (Core, Styling)
  - Swift Package Manager конфігурація

- [x] **1.2** - Управління терміналом (TerminalManager)
  - Ініціалізація та завершення сеанса
  - Перемикання в raw mode (без буферизації вводу)
  - Дизактивація echo та інші tty параметри
  - Обробка сигналів (SIGWINCH для resize)

- [x] **1.3** - Буферизація та рендеринг (ScreenBuffer)
  - Структура Cell для зберігання символів з атрибутами
  - Двійний буфер (current/previous) для diff tracking
  - Генерація мінімального набору ANSI команд
  - Вивід на stdout

- [x] **1.4** - Координатна система та розміри
  - Отримання розмірів терміналу (cols, rows)
  - Валідація координат (isValidPosition)
  - Обробка resize подій

**Реалізовано:**
- `SwiftyTermUI` - основний фасад з методами draw*, refresh(), readEvent()
- `TerminalManager` - управління raw mode, сигналами, ANSI командами
- `ScreenBuffer` - двійна буферизація з розрахунком різниці
- `InputHandler` - розпізнавання спеціальних клавіш та ANSI escape sequences
- `TextAttributes` - структура для bold, underline, italic та інших стилів
- `Color` - підтримка 8, 16 та 256 кольорів з ANSI кодами

### Етап 2: Базові компоненти (Basic Components) ✅ COMPLETED
**Мета**: примітивні операції рисування

- [x] **2.1** - Атрибути тексту (TextAttribute)
  - Перерахунок для bold, italic, underline, blink, reverse, dim
  - Комбінування атрибутів через OptionSet
  - ANSI код генерація через toAnsiCodes()

- [x] **2.2** - Кольорова система (ColorPair)
  - Палітра 8-256 кольорів
  - Пари foreground/background через ColorPair struct
  - RGB до ближайшого індексу конвертація (rgbToIndex)

- [x] **2.3** - Низькорівневе рисування
  - `addChar(y, x, char, attributes)`
  - `addString(y, x, string, attributes)`
  - `addBox(y, x, width, height, char)`
  - `clear()`, `clearArea(y, x, width, height)`

- [x] **2.4** - Курсор та видимість
  - Рух курсора (moveCursor, setCursorPosition)
  - Показ/приховання (showCursor, hideCursor)
  - Зберігання позиції та стану видимості

**Реалізовано:**
- `TextAttributes` - OptionSet з підтримкою комбінування атрибутів (bold, italic, underline, blink, reverse, dim)
- `ColorPair` - структура для пар кольорів foreground/background
- `Color.rgb()` - конвертація RGB до 256-кольорової палітри
- API для низькорівневого рисування: addChar, addString, addBox, clear, clearArea
- Управління курсором: showCursor, hideCursor, moveCursor, isCursorVisible

### Етап 3: Вікна та панелі (Windows & Panels) ✅ COMPLETED
**Мета**: управління вікнами та їх складністю

- [x] **3.1** - Вікна (Window)
  - Незалежний буфер для кожного вікна
  - Локальні координати з офсетом (move, toGlobalCoordinates)
  - Бордер та рамка опціонально (BorderStyle: single, double, rounded, custom)
  - Клавіатурний фокус (hasFocus)

- [x] **3.2** - Панелі (Panel Library)
  - Стек вікон з глибиною (PanelManager)
  - Переміщення вікна на передній план (bringToFront, sendToBack, moveUp, moveDown)
  - Приховування/відображення (hide, show, isVisible)
  - Автоматичне оновлення при змінах через renderToBuffer

- [x] **3.3** - Обробка перекриттів
  - Правильна послідовність рендеру (z-order через масив panels)
  - Рисування тільки видимих вікон (visiblePanels filter)

**Реалізовано:**
- `Window` - клас з незалежним буфером, координатами, розмірами та стилями рамки
- `PanelManager` - управління стеком вікон з z-order
- Стилі рамок: single (┌─┐), double (╔═╗), rounded (╭─╮), custom
- API для управління вікнами: createWindow, addPanel, removePanel, bringToFront, sendToBack, hideWindow, showWindow
- Підтримка заголовків вікон та фокусу (виділення рамки)

### Етап 4: Введення та поточне (Input Handling) ✅ COMPLETED
**Мета**: захоплення та обробка користувацького вводу

- [x] **4.1** - Обробка введення (InputHandler)
  - Читання сирих символів з stdin без буферизації
  - Розпізнавання ANSI sequence для спеціальних клавіш
  - Обробка стрілок, F1-F12, Home, End, Delete, Insert тощо
  - Non-blocking read через poll
  - Ctrl+клавіша та Alt+клавіша комбінації

- [x] **4.2** - Обробка подій
  - EventType: KeyPress (з усіма спеціальними клавішами), Resize
  - Система обробки Resize через SIGWINCH та NotificationCenter
  - EventQueue для обробки в правильному порядку

**Реалізовано:**
- `Key` enum з підтримкою: спеціальних клавіш (Enter, Escape, Tab, Backspace, Delete, Home, End, PageUp/Down, Insert, стрілки), функціональних клавіш (F1-F12), Ctrl+клавіша, Alt+клавіша
- `InputHandler` - розпізнавання ANSI escape sequences з non-blocking read
- `EventQueue` - черга подій з максимальним розміром для уникнення переповнення
- API: readEvent(), pollEvents(), clearEvents()
- Інтеграція з NotificationCenter для обробки resize подій

### Етап 5: Утиліти та допоміжні функції (Utilities) ✅ COMPLETED
**Мета**: загальні операції та форматування

- [x] **5.1** - Утиліти рисування
  - `drawLine(fromY, fromX, toY, toX, char)` - алгоритм Брезенхема
  - `drawRect(y, x, width, height)` - контур прямокутника
  - `fillRect(y, x, width, height, char, attrs)` - заповнений прямокутник
  - Центрування тексту (centerText, drawCenteredString)
  - Вирівнювання тексту (alignRight)

- [x] **5.2** - Форматування тексту
  - Обтікання на довжину лінії (wrap)
  - Обрізання до ширини (truncate)
  - Padding функції (padLeft, padRight, padCenter)
  - Розбиття на рядки (splitLines)
  - Підтримка ANSI кольорів у рядках (stripAnsiCodes, visualLength)

- [x] **5.3** - Допоміжні функції
  - Валідація координат (isInBounds)
  - Обмеження значень (clamp)
  - Обчислення відстані між точками (distance)
  - Конвертація кольорів (HSV↔RGB, HEX→Color)
  - Геометричні операції (intersection, rectsOverlap)

**Реалізовано:**
- `DrawingUtils` - утиліти для малювання ліній, прямокутників, центрування
- `TextUtils` - форматування, обтікання, обрізання, padding, робота з ANSI кодами
- `Helpers` - валідація, конвертація кольорів (RGB/HSV/HEX), геометричні операції
- API інтеграція: drawLine, drawRect, fillRect, drawCenteredString

### Етап 6: Вищорівневі компоненти (High-level Components)
**Мета**: готові до використання UI елементи

- [ ] **6.1** - Меню (Menu component)
  - Список обраних пунктів
  - Навігація клавіатурою (UP, DOWN, ENTER)
  - Підсвічування поточного пункту
  - Callback для вибору

- [ ] **6.2** - Форма (Form component)
  - Поля вводу (text, password)
  - Перевірка даних
  - Валідація
  - Фокус керування між полями

- [ ] **6.3** - Інші компоненти
  - Label - статичний текст
  - Button - натискна кнопка
  - TextBox - багаторядковий текст
  - ProgressBar - показник прогресу

### Етап 7: Оптимізація та доповнення (Optimization)
**Мета**: перформанс та додаткові можливості

- [ ] **7.1** - Оптимізація рендеру
  - Кешування escape sequences
  - Пакування команд в батчах
  - Мінімізація системних виклад

- [ ] **7.2** - Поширена функціональність
  - Копіювання/вставлення (якщо можливо)
  - Скролювання вікна
  - История команд (якщо застосовно)

- [ ] **7.3** - Документація та приклади
  - Документація для API
  - Приклади простих додатків (меню, форма, таблиця)
  - Гайд "Getting started"

---

## Архітектурні рішення

### 1. Модульна організація
```
SwiftyTermUI/
├── Sources/
│   ├── Core/           # Основна функціональність
│   │   ├── Terminal.swift
│   │   ├── ScreenBuffer.swift
│   │   └── InputHandler.swift
│   ├── Components/     # UI компоненти
│   │   ├── Window.swift
│   │   ├── Panel.swift
│   │   ├── Menu.swift
│   │   └── ...
│   ├── Styling/        # Кольори та атрибути
│   │   ├── Color.swift
│   │   ├── TextAttribute.swift
│   │   └── Theme.swift
│   └── Utils/          # Допоміжні функції
└── Examples/           # Приклади використання
```

### 2. Протоколи та абстракції
- `Drawable` - об'єкти яких можна рисувати на екран
- `Focusable` - об'єкти що можуть отримати фокус
- `Eventable` - об'єкти що можуть обробляти события

### 3. Життєвий цикл додатку
```
initscr()           -> Setup terminal
render()            -> Draw to buffer
refresh()           -> Send ANSI commands to stdout
handleInput()       -> Read and process input
endwin()            -> Cleanup terminal
```

### 4. Перформанс стратегія
- Double-buffering для уникнення мерехтіння
- Dirty cell tracking для мінімізації виводу
- ANSI escape последовательность оптимізація

---

## Технічні вимоги

- **Swift**: 5.9+
- **Платформи**: macOS, Linux (Unix-like)
- **Dependencies**: Мінімум (можливо тільки Darwin/Glibc для системних викликів)
- **iOS/tvOS**: На даний момент не підтримуються (відсутня підтримка термінала)

## Примітки

- Не використовуємо externe ncurses бібліотеку - писемо свою
- Фокус на simplicty та перформанс, а не на 100% сумісності з ncurses
- Будемо дотримуватись Swift API guidelines
- На кожному етапі перевіряємо базовим прикладом

