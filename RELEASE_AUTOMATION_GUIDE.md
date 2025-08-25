# MacSSH Release Automation Guide

## 🚀 Автоматизированный Релиз

Скрипт `release_automation.py` автоматизирует весь процесс создания релиза MacSSH.

## 📋 Что Делает Скрипт

1. **📝 Обновление версий** - во всех файлах проекта
2. **🔨 Локальная сборка** - компиляция в Xcode
3. **📦 Создание DMG** - упаковка в установочный файл
4. **📤 Отправка изменений** - коммит и push в Git
5. **🏷️ Создание GitHub Release** - новый релиз на GitHub
6. **📤 Загрузка DMG** - локальный файл в релиз

## ⚡ Быстрый Старт

```bash
python3 release_automation.py
```

## 🔧 Требования

- **Python 3.6+**
- **Xcode** (для сборки)
- **create-dmg** (`brew install create-dmg`)
- **GitHub CLI** (`gh`) - авторизован
- **Git** - настроен

## 📖 Подробный Процесс

### 1. Подготовка
Скрипт проверяет текущие версии и предлагает новые.

### 2. Обновление Файлов
- `MacSSH.xcodeproj/project.pbxproj` - версии Xcode
- `MacSSH/Info.plist` - версии приложения
- `appcast.xml` - информация для обновлений

### 3. Локальная Сборка
```bash
xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release clean build
```

### 4. Создание DMG
```bash
# Создается временная папка только с приложением
# Копируется MacSSH.app в /tmp/MacSSH-{version}/
# Создается DMG только с приложением
# Временная папка удаляется
create-dmg --volname 'MacSSH Installer' ... MacSSH-1.8.9.dmg
```

**Результат:** DMG содержит только приложение MacSSH.app, готовое для перетаскивания в Applications.

### 5. Git Операции
- Коммит изменений версий
- Push в main ветку

### 6. GitHub Release
- Создание нового релиза
- Загрузка локального DMG

## 🎯 Преимущества

✅ **Только локальная сборка** - никаких удаленных сборок  
✅ **Быстро** - нет ожидания GitHub Actions  
✅ **Надежно** - используем проверенный DMG  
✅ **Автоматически** - весь процесс в одном скрипте  
✅ **Чистый DMG** - только приложение для установки  

## 🔍 Проверка Результата

После завершения:
- DMG файл создан локально
- GitHub Release создан
- DMG загружен в релиз
- Ссылка на релиз выводится

## 🛠️ Устранение Проблем

### Ошибка сборки
```bash
# Проверьте Xcode
xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release clean build
```

### Ошибка create-dmg
```bash
# Установите create-dmg
brew install create-dmg
```

### Ошибка GitHub CLI
```bash
# Авторизуйтесь
gh auth login
```

## 📝 Пример Вывода

```
[14:30:15] INFO: 🚀 Начинаю автоматический релиз MacSSH
[14:30:15] INFO: Текущая версия: 1.8.8 (build 88)
[14:30:16] INFO: Новая версия: 1.8.9 (build 89)
[14:30:17] INFO: Локальная сборка завершена успешно
[14:30:25] INFO: DMG файл создан: MacSSH-1.8.9.dmg
[14:30:26] INFO: GitHub Release v1.8.9 создан
[14:30:28] INFO: DMG загружен в релиз: MacSSH-1.8.9.dmg
[14:30:28] INFO: ✅ Релиз успешно завершен!
```
