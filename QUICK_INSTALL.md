# MacSSH - Быстрая установка

## 🚀 Быстрый старт

1. **Скачайте** `.dmg` файл с [Releases](https://github.com/Solvetronix/MacSSH/releases)
2. **Установите** приложение в папку `Applications`
3. **Запустите** приложение

## ⚠️ macOS заблокировал приложение?

Это нормально! MacSSH не подписан Apple Developer ID.

### Решение:
1. **System Settings** → **Privacy & Security**
2. Найдите **"MacSSH" was blocked**
3. Нажмите **"Open Anyway"**
4. Введите пароль администратора

## 📖 Подробная инструкция

См. [docs/installation/INSTALLATION_GUIDE.md](docs/installation/INSTALLATION_GUIDE.md) для подробной инструкции с скриншотами.

## 🔧 Сборка из исходников

```bash
git clone https://github.com/Solvetronix/MacSSH.git
cd MacSSH
xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release build
```

## 🆘 Проблемы?

- Проверьте [Issues](https://github.com/Solvetronix/MacSSH/issues)
- Создайте новый Issue с описанием проблемы
