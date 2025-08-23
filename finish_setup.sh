#!/bin/bash

echo "🚀 Завершение настройки автоматического деплоя MacSSH"
echo ""

# Проверяем статус git
echo "📋 Проверяем статус git..."
git status

echo ""
echo "📝 Добавляем изменения в workflow файл..."
git add .github/workflows/auto-deploy.yml

echo ""
echo "💾 Коммитим изменения..."
git commit -m "fix: Disable code signing for automatic builds"

echo ""
echo "📤 Отправляем изменения в main ветку..."
git push origin main

echo ""
echo "✅ Настройка завершена!"
echo ""
echo "🎯 Что произойдет автоматически:"
echo "   1. GitHub Actions запустит сборку"
echo "   2. Версия увеличится: 1.8.8 → 1.8.9"
echo "   3. Создастся DMG файл без подписи"
echo "   4. Создастся GitHub Release v1.8.9"
echo "   5. Обновится версия в project.pbxproj"
echo ""
echo "🔗 Проверьте результаты:"
echo "   - Actions: https://github.com/Solvetronix/MacSSH/actions"
echo "   - Releases: https://github.com/Solvetronix/MacSSH/releases"
echo ""
echo "🎉 Система автоматического деплоя готова к работе!"


