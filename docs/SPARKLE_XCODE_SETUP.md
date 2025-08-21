# 🔧 Настройка Sparkle Framework в Xcode проекте

## 📋 Пошаговая инструкция

### 1. Откройте проект в Xcode
```bash
open MacSSH.xcodeproj
```

### 2. Добавьте Sparkle Package Dependency

1. **Выберите проект** в навигаторе Xcode
2. **Выберите target "MacSSH"**
3. **Перейдите на вкладку "Package Dependencies"**
4. **Нажмите "+" для добавления нового пакета**
5. **Введите URL репозитория Sparkle:**
   ```
   https://github.com/sparkle-project/Sparkle
   ```
6. **Выберите версию:** `Up to Next Major Version` (например, `2.5.0`)
7. **Нажмите "Add Package"**

### 3. Добавьте Sparkle в Target

1. **После добавления пакета, выберите target "MacSSH"**
2. **Перейдите на вкладку "General"**
3. **В разделе "Frameworks, Libraries, and Embedded Content"**
4. **Нажмите "+" и добавьте:**
   - `Sparkle.framework`

### 4. Настройте Info.plist

Убедитесь, что в `Info.plist` есть следующие ключи:

```xml
<!-- Sparkle Framework Configuration -->
<key>SUFeedURL</key>
<string>https://github.com/Solvetronix/MacSSH/releases.atom</string>

<key>SUEnableAutomaticChecks</key>
<true/>

<key>SUEnableAutomaticDownloads</key>
<true/>

<key>SUCheckInterval</key>
<integer>86400</integer>

<key>SUEnableSystemProfiling</key>
<false/>

<key>SUEnableLogging</key>
<true/>
```

### 5. Добавьте Menu Item (Опционально)

В `ContentView.swift` или в App Delegate добавьте пункт меню для проверки обновлений:

```swift
// В меню приложения
Button("Check for Updates...") {
    UpdateService.showUpdateWindow()
}
```

### 6. Настройте Code Signing

1. **Выберите target "MacSSH"**
2. **Перейдите в "Signing & Capabilities"**
3. **Убедитесь, что включено "Automatically manage signing"**
4. **Выберите ваш Team ID**

### 7. Настройте Entitlements

Убедитесь, что в `MacSSH.entitlements` есть необходимые разрешения:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.temporary-exception.files.absolute-path.read-write</key>
    <array>
        <string>/tmp/</string>
        <string>/var/folders/</string>
    </array>
</dict>
</plist>
```

## 🔍 Проверка настройки

### 1. Проверьте импорты в коде

Убедитесь, что в файлах есть правильные импорты:

```swift
import Sparkle
```

### 2. Проверьте сборку проекта

```bash
xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release build
```

### 3. Проверьте логи

При запуске приложения в консоли должны появиться сообщения:

```
🔧 [UpdateService] Initializing Sparkle updater...
✅ [UpdateService] Sparkle updater initialized with appcast: https://github.com/Solvetronix/MacSSH/releases.atom
```

## 🚨 Возможные проблемы

### Ошибка: "Cannot find type 'SPUUpdater'"
**Решение:** Убедитесь, что Sparkle.framework добавлен в target проекта.

### Ошибка: "No such module 'Sparkle'"
**Решение:** 
1. Проверьте, что пакет добавлен в Package Dependencies
2. Выполните `File > Packages > Reset Package Caches`
3. Выполните `File > Packages > Resolve Package Versions`

### Ошибка: "Code signing failed"
**Решение:**
1. Проверьте настройки Code Signing
2. Убедитесь, что у вас есть действующий Developer Certificate
3. Проверьте Team ID в настройках проекта

## 📝 Дополнительные настройки

### Настройка Appcast URL

Для использования GitHub Releases как appcast:

```xml
<key>SUFeedURL</key>
<string>https://github.com/Solvetronix/MacSSH/releases.atom</string>
```

### Настройка интервала проверки

```xml
<key>SUCheckInterval</key>
<integer>86400</integer>  <!-- 24 часа в секундах -->
```

### Включение логирования

```xml
<key>SUEnableLogging</key>
<true/>
```

## ✅ Готово!

После выполнения всех шагов у вас будет:

1. ✅ Автоматическая проверка обновлений при запуске
2. ✅ Автоматическая загрузка обновлений в фоне
3. ✅ Профессиональный интерфейс обновлений
4. ✅ Интеграция с GitHub Releases
5. ✅ Fallback на legacy систему при необходимости

## 🔄 Следующие шаги

1. **Соберите проект:** `xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release build`
2. **Протестируйте обновления:** Запустите приложение и проверьте логи
3. **Создайте релиз:** Добавьте новый релиз на GitHub с DMG файлом
4. **Проверьте автоматическое обновление:** Убедитесь, что приложение находит и устанавливает обновления
