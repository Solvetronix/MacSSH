# 🚀 Конфликт-Свободный Автодеплой

## ❗ Проблема которую мы решили

**Старая проблема**: Автодеплой делал коммиты в `main` ветку, что создавало конфликты при локальных изменениях.

**Новое решение**: Автодеплой только создает релизы, а версии обновляются локально.

## 🔄 Новый Рабочий Процесс

### 1. Автодеплой (GitHub Actions)
- ✅ Создает GitHub Release с DMG
- ✅ НЕ делает коммиты в репозиторий
- ✅ Показывает инструкции для ручного обновления

### 2. Локальное Обновление (Ваши действия)
После успешного автодеплоя:

```bash
# Используйте готовый скрипт
./update_version_locally.sh 1.8.13 193 MacSSH-1.8.13.dmg

# Или вручную:
# 1. Обновить project.pbxproj
sed -i '' 's/MARKETING_VERSION = 1.8.12/MARKETING_VERSION = 1.8.13/g' MacSSH.xcodeproj/project.pbxproj
sed -i '' 's/CURRENT_PROJECT_VERSION = 192/CURRENT_PROJECT_VERSION = 193/g' MacSSH.xcodeproj/project.pbxproj

# 2. Обновить appcast.xml
./update_appcast.sh 1.8.13 193 MacSSH-1.8.13.dmg

# 3. Коммит и push
git add MacSSH.xcodeproj/project.pbxproj MacSSH/Info.plist appcast.xml
git commit -m "Update version to 1.8.13 after automatic release"
git push origin main
```

## 🎯 Преимущества Нового Подхода

### ✅ Нет Конфликтов
- Автодеплой НЕ создает коммиты
- Локальные изменения не конфликтуют с удаленными
- Простой `git push` без merge конфликтов

### ✅ Контроль
- Вы видите какие версии обновляются
- Можете проверить изменения перед коммитом
- Полный контроль над appcast.xml

### ✅ Надежность
- Автодеплой не может "сломать" репозиторий
- Если что-то пойдет не так, локальные файлы остаются нетронутыми

## 📋 Пошаговая Инструкция

### Когда срабатывает автодеплой:

1. **GitHub Actions** создает релиз и DMG
2. В логах GitHub Actions вы увидите:
   ```
   ✅ Release 1.8.13 created successfully!
   📝 Manual steps to complete:
   1. Update version in project.pbxproj to 1.8.13
   2. Update appcast.xml locally  
   3. Commit and push changes
   ```

3. **Локально** выполните:
   ```bash
   # Получите последнюю информацию о релизах
   git fetch --tags
   
   # Обновите версии (замените на актуальные значения)
   ./update_version_locally.sh 1.8.13 193 MacSSH-1.8.13.dmg
   
   # Проверьте изменения
   git diff
   
   # Коммит и push
   git add MacSSH.xcodeproj/project.pbxproj MacSSH/Info.plist appcast.xml
   git commit -m "Update version to 1.8.13 after automatic release"
   git push origin main
   ```

## 🔧 Файлы в Новой Системе

### `update_version_locally.sh`
- Автоматически обновляет все файлы версий
- Проверяет корректность изменений
- Показывает команды для коммита

### `.github/workflows/auto-deploy.yml` (изменен)
- ❌ Убрана секция "Commit and push changes"
- ✅ Добавлена секция "Show manual steps info"
- ✅ Версии обновляются только для сборки, не коммитятся

## ⚠️ Важные Замечания

### Синхронизация Версий
- Всегда обновляйте версии после каждого автодеплоя
- Не пропускайте обновления - это может привести к путанице

### Порядок Действий
1. Автодеплой создает релиз
2. Вы обновляете версии локально
3. Только потом делаете новые изменения

### Проверка Версий
```bash
# Проверить текущую версию в проекте
grep 'MARKETING_VERSION = ' MacSSH.xcodeproj/project.pbxproj | head -1

# Проверить последний релиз на GitHub
git tag --sort=-version:refname | head -1
```

## 🚨 Если Что-то Пошло Не Так

### Если забыли обновить версии:
```bash
# Посмотрите последний релиз
git tag --sort=-version:refname | head -1

# Обновите до этой версии
./update_version_locally.sh <version> <build> <dmg_name>
```

### Если возникли конфликты:
```bash
# Сначала получите удаленные изменения
git fetch origin main

# Если есть конфликты, разрешите их
git pull origin main --no-rebase

# Затем обновите версии
./update_version_locally.sh <version> <build> <dmg_name>
```

## ✅ Результат

**Больше никаких конфликтов при push!** 🎉

Теперь автодеплой и локальная разработка работают независимо, но синхронно.
