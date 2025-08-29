#!/usr/bin/env python3
"""
MacSSH Release Automation Script
Автоматизирует весь процесс создания релиза:
1. Обновляет версии во всех файлах
2. Локальная сборка
3. Создание DMG
4. Создание GitHub Release
5. Загрузка DMG в релиз
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
        # Текст заметок релиза (plain) и HTML-список для appcast
        self.release_notes_text = None
        self.release_notes_html = None
        
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
        
        # Проверяем существование DMG файла
        if not os.path.exists(dmg_name):
            self.log(f"❌ Error: DMG файл {dmg_name} не найден", "ERROR")
            return
        
        # Получаем размер DMG файла
        dmg_size = os.path.getsize(dmg_name)
        
        # Получаем текущую дату
        from datetime import datetime
        current_date = datetime.utcnow().strftime("%a, %d %b %Y %H:%M:%S +0000")
        
        tag = f"v{self.new_version}"
        
        # Готовим содержимое заметок: если не заполнено, используем заглушку
        notes_html = self.release_notes_html or "<ul><li>No release notes provided</li></ul>"
        # Создаем новый элемент для appcast.xml
        new_item = f'''        <item>
            <title>MacSSH {self.new_version} - Release</title>
            <sparkle:version>{self.new_build}</sparkle:version>
            <sparkle:shortVersionString>{self.new_version}</sparkle:shortVersionString>
            <description><![CDATA[
                <h2>What's New in MacSSH {self.new_version}</h2>
                {notes_html}
            ]]></description>
            <pubDate>{current_date}</pubDate>
            <enclosure url="https://github.com/Solvetronix/MacSSH/releases/download/{tag}/{dmg_name}"
                       sparkle:os="macos"
                       length="{dmg_size}"
                       type="application/octet-stream"/>
        </item>'''
        
        # Создаем новый appcast.xml файл
        appcast_content = f'''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">

    <channel>
        <title>MacSSH Updates</title>
        <description>Most recent updates to MacSSH</description>
        <language>en</language>
        
{new_item}
    </channel>
</rss>'''
        
        # Записываем новый файл
        with open("appcast.xml", "w", encoding="utf-8") as f:
            f.write(appcast_content)
        
        self.log("appcast.xml обновлен")

    def get_last_release_tag(self):
        """Определение последнего релизного тега (v*)"""
        # Пытаемся получить ближайший тег
        result = self.run_command("git describe --tags --abbrev=0", check=False, capture_output=True)
        if result and result.returncode == 0 and result.stdout.strip():
            tag = result.stdout.strip()
            self.log(f"Последний тег: {tag}")
            return tag
        # Фолбэк: берём последний по алфавиту/версии тег вида v*
        result = self.run_command("git tag --list 'v*' | sort -V | tail -1", check=False, capture_output=True)
        if result and result.returncode == 0 and result.stdout.strip():
            tag = result.stdout.strip()
            self.log(f"Последний тег: {tag}")
            return tag
        self.log("Теги не найдены — заметки будут сгенерированы из последних коммитов", "WARNING")
        return None

    def get_commit_messages_since(self, last_tag):
        """Сбор сообщений коммитов с момента последнего тега до HEAD"""
        if last_tag:
            cmd = f"git log {last_tag}..HEAD --no-merges --pretty=format:%s"
        else:
            # Если нет тега — берём последние 20 коммитов
            cmd = "git log --no-merges --pretty=format:%s -n 20"
        result = self.run_command(cmd, check=False, capture_output=True)
        if result and result.returncode == 0 and result.stdout.strip():
            messages = [line.strip() for line in result.stdout.splitlines() if line.strip()]
            # По возможности убираем автокоммит версии из заметок
            if self.new_version:
                messages = [m for m in messages if f"Update version to {self.new_version}" not in m]
            return messages
        return []

    def format_release_notes_as_html(self, lines):
        """Преобразование списка строк заметок в HTML-список"""
        if not lines:
            return "<ul><li>No changes listed</li></ul>"
        items = "\n".join([f"<li>{line}</li>" for line in lines])
        return f"<ul>\n{items}\n</ul>"

    def prompt_release_notes(self):
        """Интерактивное получение/подтверждение заметок релиза.
        1) Пытается сгенерировать заметки из git log от последнего тега
        2) Показывает предпросмотр и спрашивает подтверждение
        3) Дает возможность ввести свои заметки (многострочно), разделяя пункты по строкам
        """
        last_tag = self.get_last_release_tag()
        commits = self.get_commit_messages_since(last_tag)
        if commits:
            print("\n📝 Предварительные заметки релиза (из коммитов):")
            for msg in commits:
                print(f" - {msg}")
            use_auto = input("\nИспользовать эти заметки? (Y/n): ").strip().lower()
            if use_auto in ("", "y", "yes"): 
                self.release_notes_text = "\n".join(commits)
                self.release_notes_html = self.format_release_notes_as_html(commits)
                return
        # Ручной ввод
        print("\nВведите заметки релиза. Каждый пункт — с новой строки. Пустая строка завершит ввод:")
        lines = []
        while True:
            try:
                line = input()
            except EOFError:
                break
            if line.strip() == "":
                break
            lines.append(line.strip())
        if not lines:
            # Последний фолбэк — используем то, что собрали (может быть пусто)
            lines = commits
        self.release_notes_text = "\n".join(lines)
        self.release_notes_html = self.format_release_notes_as_html(lines)
    
    def local_build(self):
        """Локальная сборка проекта"""
        self.log("Начинаю локальную сборку...")
        print("🔄 Сборка в процессе... (это может занять несколько минут)")
        
        # Очистка и сборка с подавлением вывода
        result = self.run_command(
            "xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release clean build",
            capture_output=True
        )
        
        if result.returncode == 0:
            self.log("✅ Локальная сборка завершена успешно")
        else:
            self.log("❌ Ошибка сборки", "ERROR")
            self.log(f"Ошибка: {result.stderr}", "ERROR")
            sys.exit(1)
    
    def create_dmg(self):
        """Создание DMG файла"""
        self.log("Создаю DMG файл...")
        
        dmg_name = f"MacSSH-{self.new_version}.dmg"
        
        # Находим путь к собранному приложению в Release конфигурации
        result = self.run_command(
            "find ~/Library/Developer/Xcode/DerivedData -name 'MacSSH.app' -path '*/Release/*' -type d | head -1",
            capture_output=True
        )
        
        if not result.stdout.strip():
            # Пробуем найти в Products/Release
            result = self.run_command(
                "find ~/Library/Developer/Xcode/DerivedData -name 'MacSSH.app' -path '*/Products/Release/*' -type d | head -1",
                capture_output=True
            )
            
        if not result.stdout.strip():
            self.log("Release версия не найдена, ищем любую версию...", "WARNING")
            # Fallback: ищем любую версию
            result = self.run_command(
                "find ~/Library/Developer/Xcode/DerivedData -name 'MacSSH.app' -type d | head -1",
                capture_output=True
            )
            
            if not result.stdout.strip():
                self.log("Не найден MacSSH.app после сборки", "ERROR")
                sys.exit(1)
        
        app_path = Path(result.stdout.strip())
        self.log(f"Найдено приложение: {app_path}")
        
        # Создаем временную папку только с приложением
        temp_dir = Path(f"/tmp/MacSSH-{self.new_version}")
        
        # Удаляем папку если она существует
        if temp_dir.exists():
            shutil.rmtree(temp_dir)
        
        temp_dir.mkdir(exist_ok=True)
        
        # Копируем только приложение
        shutil.copytree(app_path, temp_dir / "MacSSH.app")
        
        # Создаем DMG только с приложением
        self.run_command(
            f"create-dmg --volname 'MacSSH Installer' --window-pos 200 120 --window-size 800 400 "
            f"--icon-size 100 --icon 'MacSSH.app' 200 190 --hide-extension 'MacSSH.app' "
            f"--app-drop-link 600 185 '{dmg_name}' '{temp_dir}'"
        )
        
        # Очищаем временную папку
        shutil.rmtree(temp_dir)
        
        self.log(f"DMG файл создан: {dmg_name}")
        return dmg_name
    
    def commit_and_push(self):
        """Коммит и отправка изменений"""
        self.log("Коммичу и отправляю изменения...")
        
        # Добавляем файлы
        self.run_command("git add MacSSH.xcodeproj/project.pbxproj MacSSH/Info.plist appcast.xml")
        
        # Коммит
        self.run_command(f'git commit -m "Update version to {self.new_version} for release"')
        
        # Отправка
        self.run_command("git push origin main")
        
        self.log("Изменения отправлены")
    
    def create_github_release(self):
        """Создание GitHub Release"""
        self.log("Создаю GitHub Release...")
        
        # Создаем релиз
        self.run_command(
            f'gh release create v{self.new_version} '
            f'--title "MacSSH {self.new_version}" '
            f'--notes "Release {self.new_version} (build {self.new_build})"'
        )
        
        self.log(f"GitHub Release v{self.new_version} создан")
    
    def upload_dmg_to_release(self):
        """Загрузка DMG в GitHub Release"""
        self.log("Загружаю DMG в GitHub Release...")
        
        dmg_name = f"MacSSH-{self.new_version}.dmg"
        
        if not os.path.exists(dmg_name):
            self.log(f"DMG файл не найден: {dmg_name}", "ERROR")
            return
        
        # Загружаем в созданный релиз
        self.run_command(f"gh release upload v{self.new_version} {dmg_name}")
        
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
            
            # 2.1 Сбор и подтверждение заметок релиза
            self.prompt_release_notes()
            
            # Подтверждение
            print(f"\n📋 План релиза:")
            print(f"   Текущая версия: {self.current_version} (build {self.current_build})")
            print(f"   Новая версия: {self.new_version} (build {self.new_build})")
            print(f"   DMG файл: MacSSH-{self.new_version}.dmg")
            print(f"   GitHub Release: v{self.new_version}")
            if self.release_notes_text:
                print("   Заметки релиза:")
                for line in self.release_notes_text.splitlines():
                    print(f"     - {line}")
            
            confirm = input("\nПродолжить? (y/N): ").strip().lower()
            if confirm != 'y':
                self.log("Отменено пользователем")
                return
            
            # 3. Обновление версий
            self.log("\n📝 Шаг 1: Обновление версий")
            self.update_project_pbxproj()
            self.update_info_plist()
            
            # 4. Локальная сборка
            self.log("\n🔨 Шаг 2: Локальная сборка")
            self.local_build()
            
            # 5. Создание DMG
            self.log("\n📦 Шаг 3: Создание DMG")
            dmg_name = self.create_dmg()
            
            # 6. Обновление appcast.xml
            self.log("\n📝 Шаг 4: Обновление appcast.xml")
            self.update_appcast_xml()
            
            # 7. Коммит и отправка
            self.log("\n📤 Шаг 5: Отправка изменений")
            self.commit_and_push()
            
            # 8. Создание GitHub Release
            self.log("\n🏷️ Шаг 6: Создание GitHub Release")
            self.create_github_release()
            
            # 9. Загрузка DMG
            self.log("\n📤 Шаг 7: Загрузка DMG в релиз")
            self.upload_dmg_to_release()
            
            self.log("\n✅ Релиз успешно завершен!")
            self.log(f"🎉 Новая версия {self.new_version} доступна на GitHub")
            self.log(f"🔗 Релиз: https://github.com/Solvetronix/MacSSH/releases/tag/v{self.new_version}")
            
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
4. Отправляет изменения в Git
5. Создает GitHub Release
6. Загружает локальный DMG в релиз

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
