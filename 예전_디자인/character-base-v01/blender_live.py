"""열려 있는 Blender의 MCP 애드온(localhost:9876)에 명령을 보낸다.

실행: python blender_live.py info
      python blender_live.py run <파이썬 파일>
"""
import json
import socket
import sys
from pathlib import Path

HOST, PORT = "localhost", 9876


def send(command_type: str, params: dict | None = None, timeout: float = 120.0) -> dict:
    with socket.create_connection((HOST, PORT), timeout=timeout) as client:
        client.sendall(json.dumps({"type": command_type, "params": params or {}}).encode("utf-8"))
        buffer = b""
        while True:
            chunk = client.recv(65536)
            if not chunk:
                raise ConnectionError("Blender가 응답 도중 연결을 닫았습니다.")
            buffer += chunk
            try:
                return json.loads(buffer.decode("utf-8"))
            except ValueError:
                continue


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    if sys.argv[1] == "info":
        print(json.dumps(send("get_scene_info"), ensure_ascii=False, indent=1))
    elif sys.argv[1] == "run":
        code = Path(sys.argv[2]).read_text(encoding="utf-8")
        print(json.dumps(send("execute_code", {"code": code}), ensure_ascii=False, indent=1))
