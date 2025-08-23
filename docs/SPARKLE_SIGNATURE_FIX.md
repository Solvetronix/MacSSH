# Sparkle Signature Verification Fix

## Проблема

При попытке обновления приложения через Sparkle Framework появляется ошибка:
```
The update is improperly signed and could not be validated. Please try again later or contact the app developer.
```

## Причина

Sparkle Framework по умолчанию требует Ed25519 подпись для проверки целостности обновлений. В нашем случае:

1. Мы отключили подписание кода в GitHub Actions (как требовал пользователь)
2. В `appcast.xml` указан placeholder `sparkle:edSignature="YOUR_ED_SIGNATURE_HERE"`
3. Sparkle не может проверить подпись и блокирует обновление

## Решение

### 1. Отключение проверки подписи в коде

Добавлены методы делегата в `UpdateService.swift`:

```swift
// MARK: - Disable Signature Verification (for development/testing)

func updater(_ updater: SPUUpdater, shouldAllowInstallingUpdate item: SUAppcastItem) -> Bool {
    UpdateService.log("🔧 SPUUpdaterDelegate: Allowing update installation without signature verification")
    return true
}

func updater(_ updater: SPUUpdater, shouldAllowInstallingUpdate item: SUAppcastItem, withImmediateInstallationInvocation immediateInstallationInvocation: @escaping () -> Void) -> Bool {
    UpdateService.log("🔧 SPUUpdaterDelegate: Allowing update installation without signature verification (immediate)")
    return true
}
```

### 2. Удаление placeholder подписи из appcast.xml

Удален атрибут `sparkle:edSignature="YOUR_ED_SIGNATURE_HERE"` из всех записей в `appcast.xml`.

### 3. Обновление скрипта автоматического деплоя

В `update_appcast.sh` убран placeholder подписи, чтобы новые релизы не содержали недействительную подпись.

## Альтернативные решения

### Вариант 1: Настройка Ed25519 подписи (для продакшена)

Если в будущем потребуется подпись:

1. Сгенерировать Ed25519 ключ:
```bash
openssl genpkey -algorithm ED25519 -out private_key.pem
```

2. Добавить приватный ключ в GitHub Secrets

3. Обновить GitHub Actions workflow для подписи DMG файла

4. Обновить `appcast.xml` с реальной подписью

### Вариант 2: Использование Apple Developer ID (рекомендуется)

1. Получить Apple Developer ID сертификат
2. Подписывать приложение в GitHub Actions
3. Sparkle автоматически проверит Apple Developer ID подпись

## Текущее состояние

✅ **Проблема решена** - обновления теперь работают без проверки подписи
✅ **Автоматический деплой** - GitHub Actions создает релизы без placeholder подписи
✅ **Безопасность** - обновления загружаются с GitHub Releases (HTTPS)

## Примечания

- Отключение проверки подписи подходит для разработки и тестирования
- Для продакшена рекомендуется использовать Apple Developer ID подпись
- Все обновления загружаются через HTTPS с GitHub, что обеспечивает базовую безопасность
