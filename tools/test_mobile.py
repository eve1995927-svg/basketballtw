#!/usr/bin/env python3
"""Run offline Godot regression tests in a separate project and user-data folder."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import uuid

parser = argparse.ArgumentParser()
parser.add_argument('--godot', default='/Applications/Godot.app/Contents/MacOS/Godot')
parser.add_argument('--visual', action='store_true')
parser.add_argument('--layout', action='store_true', help='Run cross-size layout assertions headlessly, without screenshots')
parser.add_argument('--sizes', help='Optional visual sizes, e.g. 568x320,844x390')
parser.add_argument('--desktop', action='store_true', help='Exercise desktop UI path (headless only)')
parser.add_argument('--local-data', action='store_true', help='Relocate save paths in disposable script copies to the temporary directory (restricted macOS runners)')
parser.add_argument('--touch', action='store_true', help='Inject real touch events and assert scroll/click behavior')
parser.add_argument('--full', action='store_true', help='Extended catalog, economy, saves, season and screen audit')
parser.add_argument('--fitshot', action='store_true', help='Capture the built-in 844x390 iPhone UI tour using disposable save data')
parser.add_argument('--verbose', action='store_true')
parser.add_argument('--pack', help='Verify an exported PCK in an otherwise empty project')
parser.add_argument('--output', default='playtest/mobile_audit')
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='tb-mobile-test-') as temp:
    project = Path(temp)
    # Imported resources are reused read-only. No editor/import is run here.
    for name in (() if args.pack else ('assets', 'data', 'scripts', 'tests', 'shaders', '.godot')):
        if args.local_data and name in ('scripts', 'tests'):
            shutil.copytree(repo / name, project / name)
        else:
            (project / name).symlink_to(repo / name, target_is_directory=True)
    if args.fitshot:
        (project / 'main.tscn').symlink_to(repo / 'main.tscn')
    config = (repo / 'project.godot').read_text()
    config = config.replace('config/name="台籃模擬器"', f'config/name="TB-Mobile-Test-{uuid.uuid4().hex}"')
    if args.local_data:
        # Godot's macOS user-data root is fixed under Library. Do not change HOME
        # or request access to it; all game/test save literals use a private temp dir.
        data_dir = project / 'test-data'
        data_dir.mkdir()
        # PCK smoke tests only mount/read the archive; its contents stay unchanged.
        for folder in (() if args.pack else ('scripts', 'tests')):
            for script_file in (project / folder).rglob('*.gd'):
                source = script_file.read_text()
                source = source.replace('user://', data_dir.as_posix() + '/')
                source = source.replace('OS.get_user_data_dir()', '"' + data_dir.as_posix() + '"')
                script_file.write_text(source)
        # Existing engine directory is read-only; logging is redirected below.
        config = config.replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="Godot"')
        config += '\n[network]\n\ntls/certificate_bundle_override="/etc/ssl/cert.pem"\n'
    if args.touch:
        config = config.replace('pointing/emulate_mouse_from_touch=true', 'pointing/emulate_mouse_from_touch=true\npointing/emulate_touch_from_mouse=true')
    (project / 'project.godot').write_text(config)
    environment = os.environ.copy()
    for key in list(environment):
        if key.startswith('TB_'):
            environment.pop(key)
    if args.pack:
        shutil.copy2(repo / 'tests/export_smoke.gd', project / 'export_smoke.gd')
        environment['TB_TEST_PACK'] = str(Path(args.pack).resolve())
    environment['TB_TEST_DESKTOP'] = '1' if args.desktop else '0'
    environment['TB_TEST_SIZES'] = args.sizes or ''
    environment['TB_TEST_VISUAL'] = '1' if args.visual else '0'
    environment['TB_TEST_LAYOUT'] = '1' if args.layout else '0'
    environment['TB_TEST_OUTPUT'] = str((repo / args.output).resolve())
    if args.fitshot:
        environment['TB_FITSHOT'] = '1'
    script = 'res://tests/touch_regression.gd' if args.touch else ('res://tests/full_regression.gd' if args.full else 'res://tests/mobile_regression.gd')
    command = [args.godot, '--path', str(project)]
    if not args.fitshot:
        command.extend(['--script', 'res://export_smoke.gd' if args.pack else script])
    command.extend(['--audio-driver', 'Dummy'])
    if args.local_data:
        command.extend(['--log-file', str(project / 'godot.log')])
    if args.verbose:
        command.append("--verbose")
    if not args.visual:
        command.append('--headless')
    process = subprocess.Popen(command, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    lines = []
    def consume_output():
        for line in process.stdout:
            lines.append(line)
            print(line, end='', flush=True)
            if 'SCRIPT ERROR:' in line:
                process.kill()  # A broken SceneTree script may otherwise never quit.
    reader = threading.Thread(target=consume_output, daemon=True)
    reader.start()
    try:
        process.wait(timeout=180)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
        print('ERROR: Test exceeded 180 seconds', flush=True)
    reader.join(timeout=5)
    result = subprocess.CompletedProcess(command, process.returncode, ''.join(lines))
    for line in result.stdout.splitlines():
        if line.startswith('TEST_USER_DIR='):
            user_dir = Path(line.removeprefix('TEST_USER_DIR='))
            if user_dir.name.startswith('TB-Mobile-Test-') and user_dir.is_dir():
                shutil.rmtree(user_dir)
    # Godot may return zero even when a runtime script error interrupted a test.
    success_marker = True if args.fitshot else 'failures=0' in result.stdout
    success = result.returncode == 0 and success_marker and 'SCRIPT ERROR' not in result.stdout and 'ERROR:' not in result.stdout
    raise SystemExit(0 if success else 1)
