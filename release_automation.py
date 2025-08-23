#!/usr/bin/env python3
"""
MacSSH Release Automation Script
Автоматизирует весь процесс создания релиза:
1. Обновляет версии во всех файлах
2. Локальная сборка
3. Создание DMG
4. Автодеплой на GitHub
"""

import os
import sys
import subprocess
import re
import time
import shutil
from pathlib import Path

class MacSSHReleaseAutomation:
    def __init__(self):
        self.project_root = Path.cwd()
        self.xcode_project = self.project_root / "MacSSH.xcodeproj" / "project.pbxproj"
        self.info_plist = self.project_root / "MacSSH" / "Info.plist"
        self.appcast_xml = self.project_root / "appcast.xml"
        
        # Текущие версии
        self.current_version = None
        self.current_build = None
        self.new_version = None
        self.new_build = None
        
    def log(self, message, level="INFO"):
        """Логирование с временными метками"""
        timestamp = time.strftime("%H:%M:%S")
        print(f"[{timestamp}] {level}: {message}")
    
    def run_command(self, command, check=True, capture_output=True):
        """Выполнение команды с обработкой ошибок"""
        self.log(f"Выполняю: {command}")
        try:
            result = subprocess.run(
                command, 
                shell=True, 
                check=check, 
                capture_output=capture_output,
                text=True,
                cwd=self.project_root
            )
            if capture_output and result.stdout:
                self.log(f"Вывод: {result.stdout.strip()}")
            return result
        except subprocess.CalledProcessError as e:
            self.log(f"Ошибка выполнения команды: {e}", "ERROR")
            if e.stderr:
                self.log(f"Stderr: {e.stderr}", "ERROR")
            if not check:
                return e
            sys.exit(1)
    
    def get_current_versions(self):
        """Получение текущих версий из project.pbxproj"""
        self.log("Получаю текущие версии...")
        
        # Читаем project.pbxproj
        with open(self.xcode_project, 'r') as f:
            content = f.read()
        
        # Ищем MARKETING_VERSION
        version_match = re.search(r'MARKETING_VERSION = ([^;]+);', content)
        if not version_match:
            self.log("Не найден MARKETING_VERSION в project.pbxproj", "ERROR")
            sys.exit(1)
        
        self.current_version = version_match.group(1).strip()
        
        # Ищем CURRENT_PROJECT_VERSION
        build_match = re.search(r'CURRENT_PROJECT_VERSION = ([^;]+);', content)
        if not build_match:
            self.log("Не найден CURRENT_PROJECT_VERSION в project.pbxproj", "ERROR")
            sys.exit(1)
        
        self.current_build = build_match.group(1).strip()
        
        self.log(f"Текущая версия: {self.current_version} (build {self.current_build})")
    
    def calculate_new_versions(self):
        """Вычисление новых версий"""
        self.log("Вычисляю новые версии...")
        
        # Парсим текущую версию
        parts = self.current_version.split('.')
        if len(parts) != 3:
            self.log("Неверный формат версии", "ERROR")
            sys.exit(1)
        
        major, minor, patch = parts
        new_patch = int(patch) + 1
        self.new_version = f"{major}.{minor}.{new_patch}"
        self.new_build = str(int(self.current_build) + 1)
        
        self.log(f"Новая версия: {self.new_version} (build {self.new_build})")
    
    def update_project_pbxproj(self):
        """Обновление версий в project.pbxproj"""
        self.log("Обновляю project.pbxproj...")
        
        with open(self.xcode_project, 'r') as f:
            content = f.read()
        
        # Заменяем версии
        content = re.sub(
            f'MARKETING_VERSION = {self.current_version};',
            f'MARKETING_VERSION = {self.new_version};',
            content
        )
        
        content = re.sub(
            f'CURRENT_PROJECT_VERSION = {self.current_build};',
            f'CURRENT_PROJECT_VERSION = {self.new_build};',
            content
        )
        
        with open(self.xcode_project, 'w') as f:
            f.write(content)
        
        self.log("project.pbxproj обновлен")
    
    def update_info_plist(self):
        """Обновление версии в Info.plist"""
        self.log("Обновляю Info.plist...")
        
        with open(self.info_plist, 'r') as f:
            content = f.read()
        
        # Заменяем CFBundleShortVersionString
        content = re.sub(
            f'<string>{self.current_version}</string>',
            f'<string>{self.new_version}</string>',
            content
        )
        
        # Заменяем CFBundleVersion
        content = re.sub(
            f'<key>CFBundleVersion</key>\\s*<string>{self.current_build}</string>',
            f'<key>CFBundleVersion</key>\\n\\t<string>{self.new_build}</string>',
            content
        )
        
        with open(self.info_plist, 'w') as f:
            f.write(content)
        
        self.log("Info.plist обновлен")
    
    def update_appcast_xml(self):
        """Обновление appcast.xml"""
        self.log("Обновляю appcast.xml...")
        
        dmg_name = f"MacSSH-{self.new_version}.dmg"
        
        # Запускаем update_appcast.sh
        self.run_command(f"./update_appcast.sh {self.new_version} {self.new_build} {dmg_name}")
        
        self.log("appcast.xml обновлен")
    
    def local_build(self):
        """Локальная сборка проекта"""
        self.log("Начинаю локальную сборку...")
        
        # Очистка и сборка
        self.run_command(
            "xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release clean build"
        )
        
        self.log("Локальная сборка завершена успешно")
    
    def create_dmg(self):
        """Создание DMG файла"""
        self.log("Создаю DMG файл...")
        
        dmg_name = f"MacSSH-{self.new_version}.dmg"
        
        # Находим путь к собранному приложению
        result = self.run_command(
            "find ~/Library/Developer/Xcode/DerivedData -name 'MacSSH.app' -type d | head -1",
            capture_output=True
        )
        
        if not result.stdout.strip():
            self.log("Не найден MacSSH.app после сборки", "ERROR")
            sys.exit(1)
        
        app_path = Path(result.stdout.strip())
        build_dir = app_path.parent
        
        # Создаем DMG
        self.run_command(
            f"create-dmg --volname 'MacSSH Installer' --window-pos 200 120 --window-size 800 400 "
            f"--icon-size 100 --icon 'MacSSH.app' 200 190 --hide-extension 'MacSSH.app' "
            f"--app-drop-link 600 185 '{dmg_name}' '{build_dir}'"
        )
        
        self.log(f"DMG файл создан: {dmg_name}")
        return dmg_name
    
    def commit_and_push(self):
        """Коммит и отправка изменений"""
        self.log("Коммичу и отправляю изменения...")
        
        # Добавляем файлы
        self.run_command("git add MacSSH.xcodeproj/project.pbxproj MacSSH/Info.plist appcast.xml")
        
        # Коммит
        self.run_command(f'git commit -m "Update version to {self.new_version} for release"')
        
        # Отправка (запустит автодеплой)
        self.run_command("git push origin main")
        
        self.log("Изменения отправлены, автодеплой запущен")
    
    def wait_for_autodeploy(self):
        """Ожидание завершения автодеплоя"""
        self.log("Ожидаю завершения автодеплоя...")
        self.log("Проверьте GitHub Actions: https://github.com/Solvetronix/MacSSH/actions")
        self.log("Нажмите Enter когда автодеплой завершится...")
        input()
    
    def upload_dmg_to_release(self):
        """Загрузка DMG в GitHub Release"""
        self.log("Загружаю DMG в GitHub Release...")
        
        dmg_name = f"MacSSH-{self.new_version}.dmg"
        
        if not os.path.exists(dmg_name):
            self.log(f"DMG файл не найден: {dmg_name}", "ERROR")
            return
        
        # Загружаем в последний релиз
        self.run_command(f"gh release upload latest {dmg_name}")
        
        self.log(f"DMG загружен в релиз: {dmg_name}")
    
    def run_full_release(self):
        """Запуск полного процесса релиза"""
        self.log("🚀 Начинаю автоматический релиз MacSSH")
        self.log("=" * 50)
        
        try:
            # 1. Получение текущих версий
            self.get_current_versions()
            
            # 2. Вычисление новых версий
            self.calculate_new_versions()
            
            # Подтверждение
            print(f"\n📋 План релиза:")
            print(f"   Текущая версия: {self.current_version} (build {self.current_build})")
            print(f"   Новая версия: {self.new_version} (build {self.new_build})")
            print(f"   DMG файл: MacSSH-{self.new_version}.dmg")
            
            confirm = input("\nПродолжить? (y/N): ").strip().lower()
            if confirm != 'y':
                self.log("Отменено пользователем")
                return
            
            # 3. Обновление версий
            self.log("\n📝 Шаг 1: Обновление версий")
            self.update_project_pbxproj()
            self.update_info_plist()
            self.update_appcast_xml()
            
            # 4. Локальная сборка
            self.log("\n🔨 Шаг 2: Локальная сборка")
            self.local_build()
            
            # 5. Создание DMG
            self.log("\n📦 Шаг 3: Создание DMG")
            dmg_name = self.create_dmg()
            
            # 6. Коммит и автодеплой
            self.log("\n🚀 Шаг 4: Запуск автодеплоя")
            self.commit_and_push()
            
            # 7. Ожидание автодеплоя
            self.log("\n⏳ Шаг 5: Ожидание автодеплоя")
            self.wait_for_autodeploy()
            
            # 8. Загрузка DMG
            self.log("\n📤 Шаг 6: Загрузка DMG в релиз")
            self.upload_dmg_to_release()
            
            self.log("\n✅ Релиз успешно завершен!")
            self.log(f"🎉 Новая версия {self.new_version} доступна на GitHub")
            
        except KeyboardInterrupt:
            self.log("Процесс прерван пользователем", "WARNING")
        except Exception as e:
            self.log(f"Ошибка: {e}", "ERROR")
            sys.exit(1)

def main():
    """Главная функция"""
    if len(sys.argv) > 1 and sys.argv[1] == "--help":
        print("""
MacSSH Release Automation Script

Использование:
    python3 release_automation.py

Что делает скрипт:
1. Обновляет версии во всех файлах (project.pbxproj, Info.plist, appcast.xml)
2. Выполняет локальную сборку проекта
3. Создает DMG файл
4. Запускает автодеплой на GitHub
5. Загружает DMG в созданный релиз

Требования:
- Python 3.6+
- Xcode
- create-dmg (brew install create-dmg)
- GitHub CLI (gh)
- Git
        """)
        return
    
    automation = MacSSHReleaseAutomation()
    automation.run_full_release()

if __name__ == "__main__":
    main()
