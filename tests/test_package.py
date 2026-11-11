import os, pathlib, subprocess, tempfile, unittest, shutil
ROOT = pathlib.Path(__file__).resolve().parents[1]
BASH = shutil.which('bash') or (r'C:\Program Files\Git\bin\bash.exe' if os.name == 'nt' else None)
PS = shutil.which('powershell') or shutil.which('pwsh')

class PackageTests(unittest.TestCase):
    @unittest.skipUnless(BASH, 'bash unavailable')
    def test_secret_output_is_suppressed(self):
        with tempfile.TemporaryDirectory() as d:
            root = pathlib.Path(d)
            bin_dir = root / 'bin'; bin_dir.mkdir()
            stub = bin_dir / 'gitleaks'
            stub.write_text('#!/bin/sh\necho FAKE_SECRET_VALUE\nexit 1\n', encoding='utf-8')
            stub.chmod(0o755)
            env = os.environ.copy(); env['PATH'] = str(bin_dir) + os.pathsep + env['PATH']
            result = subprocess.run([BASH, str(ROOT / 'skills/review-loop/scripts/gate.sh'), str(root)], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertNotIn('FAKE_SECRET_VALUE', result.stdout + result.stderr)
            self.assertIn('| secrets | FAIL |', result.stdout)

    @unittest.skipUnless(BASH, 'bash unavailable')
    def test_shell_installer_rejects_invalid_and_keeps_backups(self):
        with tempfile.TemporaryDirectory() as d:
            cmd = [BASH, str(ROOT / 'install.sh'), d]
            bad = subprocess.run(cmd + ['typo'], capture_output=True, text=True)
            self.assertNotEqual(bad.returncode, 0)
            for _ in range(3):
                result = subprocess.run(cmd + ['both'], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(len(list((pathlib.Path(d) / '.claude/skills').glob('review-loop.bak-*'))), 2)
            self.assertEqual(len(list((pathlib.Path(d) / '.cursor/rules').glob('*.bak-*'))), 2)

    @unittest.skipUnless(PS, 'PowerShell unavailable')
    def test_powershell_installer_rejects_invalid_and_keeps_backups(self):
        with tempfile.TemporaryDirectory() as d:
            cmd = [PS, '-NoProfile', '-File', str(ROOT / 'install.ps1'), d]
            bad = subprocess.run(cmd + ['typo'], capture_output=True, text=True)
            self.assertNotEqual(bad.returncode, 0)
            for _ in range(3):
                result = subprocess.run(cmd + ['both'], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(len(list((pathlib.Path(d) / '.claude/skills').glob('review-loop.bak-*'))), 2)
            self.assertEqual(len(list((pathlib.Path(d) / '.cursor/rules').glob('*.bak-*'))), 2)

if __name__ == '__main__': unittest.main()
