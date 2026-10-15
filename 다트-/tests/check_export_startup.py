"""내보낸 Windows 실행 파일의 기본 시작과 명시적 파일 로그를 검증한다."""

import argparse
import ctypes
import subprocess
import time
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", type=Path, required=True)
    parser.add_argument("--client", type=Path, required=True)
    args = parser.parse_args()
    # 실패해도 Windows 오류 대화상자가 자동 검증을 무기한 막지 않게 한다.
    ctypes.windll.kernel32.SetErrorMode(0x0001 | 0x0002)
    folder = Path(__file__).resolve().parents[1] / ".godot" / "startup_tests" / str(time.time_ns())
    folder.mkdir(parents=True)
    server = args.server.resolve()
    client = args.client.resolve()
    explicit_log = folder / "explicit.engine.log"
    cases = [
        ("server_default", server, []),
        ("console_default", server.with_name(server.stem + ".console.exe"), []),
        ("server_explicit", server, ["--log-file", str(explicit_log)]),
        ("client_default", client, []),
    ]
    for name, binary, options in cases:
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
        result = subprocess.run(
            [str(binary), "--quit-after", "60", *options], cwd=binary.parent,
            capture_output=True, timeout=20, startupinfo=startup,
        )
        output = (result.stdout + result.stderr).decode("utf-8", errors="replace")
        (folder / (name + ".log")).write_text(output, encoding="utf-8")
        assert result.returncode == 0, (name, result.returncode, output)
        lines = [line.strip() for line in output.splitlines() if line.strip()]
        errors = []
        cache_errors = 0
        for index, line in enumerate(lines):
            if "ERROR:" not in line and "CrashHandlerException" not in line:
                continue
            if "root certificate store" in line:
                continue
            if (line == 'ERROR: Condition "f.is_null()" is true.' and index + 1 < len(lines)
                    and lines[index + 1].startswith("at: _save_to_cache (servers/rendering/renderer_rd/shader_rd.cpp:")):
                cache_errors += 1
                continue
            errors.append(line)
        assert not errors, (name, errors)
        if cache_errors:
            print(f"ENV: {name}, shader cache write errors: {cache_errors}", flush=True)
        if name.startswith("server"):
            assert "Dedicated server listening" in output, output
        if name == "client_default":
            assert "D3D12" in output and "Dedicated server listening" not in output, output
        print(f"PASS: {name}, exit 0", flush=True)
    assert "Dedicated server listening" in explicit_log.read_text(encoding="utf-8")
    print(f"All checks passed. Logs: {folder}", flush=True)


if __name__ == "__main__":
    main()
