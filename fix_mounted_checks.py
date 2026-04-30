#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
自动修复 Flutter 项目中缺失的 mounted 检查

修复模式：
1. 在异步操作后的 setState 前添加 if (!mounted) return;
2. 在异步操作后的 ScaffoldMessenger 前添加 if (!mounted) return;
"""

import re
import os
import sys
from pathlib import Path

# 设置输出编码为 UTF-8
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

def fix_mounted_checks(file_path):
    """修复单个文件中的 mounted 检查"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content
    changes = []

    # 模式1: 修复 setState 前缺少 mounted 检查
    # 查找: await ... setState(
    # 在 setState 前添加: if (!mounted) return;
    pattern1 = r'(await\s+[^;]+;)\s*\n(\s*)(setState\s*\()'

    def replace1(match):
        await_line = match.group(1)
        indent = match.group(2)
        setstate = match.group(3)

        # 检查前面是否已经有 mounted 检查
        before = content[:match.start()]
        if 'if (!mounted) return;' in before[-100:] or 'if (mounted)' in before[-100:]:
            return match.group(0)

        changes.append(f"Added mounted check before setState at line {content[:match.start()].count(chr(10)) + 1}")
        return f"{await_line}\n{indent}if (!mounted) return;\n{indent}{setstate}"

    content = re.sub(pattern1, replace1, content)

    # 模式2: 修复 ScaffoldMessenger 前缺少 mounted 检查
    # 查找: await ... ScaffoldMessenger.of(context)
    pattern2 = r'(await\s+[^;]+;)\s*\n(\s*)(ScaffoldMessenger\.of\(context\))'

    def replace2(match):
        await_line = match.group(1)
        indent = match.group(2)
        scaffold = match.group(3)

        # 检查前面是否已经有 mounted 检查
        before = content[:match.start()]
        if 'if (!mounted) return;' in before[-100:] or 'if (mounted)' in before[-100:]:
            return match.group(0)

        changes.append(f"Added mounted check before ScaffoldMessenger at line {content[:match.start()].count(chr(10)) + 1}")
        return f"{await_line}\n{indent}if (!mounted) return;\n{indent}{scaffold}"

    content = re.sub(pattern2, replace2, content)

    # 模式3: 修复 setState 在 try-catch 中的情况
    # 查找: } catch ... setState(
    pattern3 = r'(\}\s*catch\s*\([^)]*\)\s*\{[^}]*)\n(\s*)(setState\s*\()'

    def replace3(match):
        catch_block = match.group(1)
        indent = match.group(2)
        setstate = match.group(3)

        # 检查是否已经有 mounted 检查
        if 'if (!mounted) return;' in catch_block or 'if (mounted)' in catch_block:
            return match.group(0)

        changes.append(f"Added mounted check in catch block at line {content[:match.start()].count(chr(10)) + 1}")
        return f"{catch_block}\n{indent}if (!mounted) return;\n{indent}{setstate}"

    content = re.sub(pattern3, replace3, content)

    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        return changes

    return []

def main():
    """扫描并修复所有 Dart 文件"""
    project_root = Path(__file__).parent
    lib_dir = project_root / 'lib'

    if not lib_dir.exists():
        print(f"Error: {lib_dir} not found")
        return

    total_changes = 0
    fixed_files = []

    # 优先修复的文件
    priority_files = [
        'lib/pages/login.dart',
        'lib/pages/actives/sign_in/sign_in.dart',
        'lib/pages/actives/sign_in/normal.dart',
        'lib/pages/actives/sign_in/qrcode.dart',
        'lib/pages/actives/sign_in/code.dart',
        'lib/pages/actives/sign_in/location.dart',
        'lib/pages/actives/sign_in/pattern.dart',
        'lib/pages/courses.dart',
    ]

    print("开始修复 mounted 检查问题...\n")

    # 先修复优先文件
    for file_path in priority_files:
        full_path = project_root / file_path
        if full_path.exists():
            changes = fix_mounted_checks(full_path)
            if changes:
                fixed_files.append(file_path)
                total_changes += len(changes)
                print(f"[OK] {file_path}")
                for change in changes:
                    print(f"   - {change}")

    # 然后修复其他文件
    for dart_file in lib_dir.rglob('*.dart'):
        rel_path = dart_file.relative_to(project_root)
        if str(rel_path) not in priority_files:
            changes = fix_mounted_checks(dart_file)
            if changes:
                fixed_files.append(str(rel_path))
                total_changes += len(changes)
                print(f"✅ {rel_path}")
                for change in changes:
                    print(f"   - {change}")

    print(f"\n修复完成:")
    print(f"   - 修复文件数: {len(fixed_files)}")
    print(f"   - 总修复数: {total_changes}")

    if fixed_files:
        print(f"\n请运行 'flutter analyze' 验证修复结果")

if __name__ == '__main__':
    main()
