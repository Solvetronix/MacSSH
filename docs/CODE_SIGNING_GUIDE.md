# MacSSH Code Signing Guide

## 🔐 Подпись приложения Apple Developer ID

Это руководство поможет настроить подпись приложения MacSSH сертификатом Apple Developer ID, что устранит предупреждения Gatekeeper.

## 📋 Требования

### 1. Apple Developer Account
- **Платный аккаунт** ($99/год) - полный доступ
- **Бесплатный аккаунт** - ограниченные возможности, но работает для личного использования

### 2. Xcode
- Xcode 15.0 или новее
- Настроенный Apple ID в Xcode

## 🚀 Пошаговая настройка

### Шаг 1: Настройка Apple ID в Xcode

1. **Откройте Xcode**
2. Перейдите в **Xcode → Settings → Accounts**
3. Нажмите **"+"** и добавьте ваш Apple ID
4. Войдите в систему

### Шаг 2: Настройка подписи в проекте

1. **Откройте проект MacSSH** в Xcode
2. Выберите проект **MacSSH** в навигаторе
3. Выберите target **MacSSH**
4. Перейдите на вкладку **"Signing & Capabilities"**

#### Настройки подписи:
```
✅ Automatically manage signing
Team: [Ваш Apple ID]
Bundle Identifier: solvetronix.macssh
```

### Шаг 3: Создание сертификата

#### Для платного аккаунта:
1. В Xcode выберите **"Apple Development"** сертификат
2. Xcode автоматически создаст сертификат

#### Для бесплатного аккаунта:
1. Выберите **"Personal Team"**
2. Используйте **"Apple Development"** сертификат
3. Приложение будет работать только на вашем Mac

### Шаг 4: Настройка Entitlements

Файл `MacSSH.entitlements` уже настроен:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

## 🔧 Командная строка подписи

### Автоматическая подпись через Xcode

```bash
# Сборка с автоматической подписью
xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release -archivePath build/MacSSH.xcarchive archive

# Экспорт подписанного приложения
xcodebuild -exportArchive -archivePath build/MacSSH.xcarchive -exportPath build/ -exportOptionsPlist exportOptions.plist
```

### Ручная подпись

```bash
# Подпись приложения
codesign --force --deep --sign "Developer ID Application: Your Name" /path/to/MacSSH.app

# Проверка подписи
codesign --verify --deep --strict /path/to/MacSSH.app

# Проверка деталей подписи
codesign -dv /path/to/MacSSH.app
```

## 📦 Создание подписанного DMG

### 1. Подготовка приложения
```bash
# Убедитесь, что приложение подписано
codesign --verify --deep --strict /path/to/MacSSH.app

# Снимите карантин если нужно
xattr -rd com.apple.quarantine /path/to/MacSSH.app
```

### 2. Создание DMG
```bash
# Создайте DMG с подписанным приложением
# Используйте любой DMG creation tool
# Убедитесь, что технические файлы удалены
```

### 3. Подпись DMG (опционально)
```bash
# Подпись DMG файла
codesign --force --deep --sign "Developer ID Application: Your Name" MacSSH-1.8.7.dmg
```

## 🧪 Тестирование подписи

### Проверка на чистой системе
1. **Скопируйте** подписанное приложение на другой Mac
2. **Попробуйте запустить** - не должно быть предупреждений Gatekeeper
3. **Проверьте** через Terminal:
   ```bash
   codesign --verify --deep --strict /Applications/MacSSH.app
   ```

### Проверка через Terminal
```bash
# Проверка подписи
codesign --verify --deep --strict /Applications/MacSSH.app

# Детальная информация о подписи
codesign -dv /Applications/MacSSH.app

# Проверка entitlements
codesign -d --entitlements :- /Applications/MacSSH.app
```

## ⚠️ Важные моменты

### Для бесплатного аккаунта:
- Приложение работает только на вашем Mac
- Пользователи увидят предупреждение "неизвестный разработчик"
- Нужно щелкнуть правой кнопкой → "Открыть"

### Для платного аккаунта:
- Приложение работает на всех Mac
- Нет предупреждений Gatekeeper
- Можно распространять через интернет

## 🔄 Обновление инструкции по релизу

После настройки подписи обновите `docs/RELEASE_INSTRUCTIONS.md`:

```markdown
### Code Signing (Обязательно)
- [ ] Приложение подписано Developer ID сертификатом
- [ ] Проверена подпись: `codesign --verify --deep --strict`
- [ ] Протестировано на чистой системе
```

## 📞 Устранение проблем

### Ошибка "No signing certificate found"
1. Проверьте настройки Apple ID в Xcode
2. Убедитесь, что сертификат создан
3. Проверьте настройки подписи в проекте

### Ошибка "Code signing is required"
1. Включите "Automatically manage signing"
2. Выберите правильную команду (Team)
3. Проверьте Bundle Identifier

### Приложение не запускается после подписи
1. Проверьте entitlements
2. Убедитесь, что все зависимости подписаны
3. Проверьте логи в Console.app

---

**Результат**: Приложение будет подписано и не будет показывать предупреждения Gatekeeper!
