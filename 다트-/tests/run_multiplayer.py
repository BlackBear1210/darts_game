"""Godot 실제 프로세스 2~5개로 로비와 공동 입장을 검증한다."""

import argparse
import json
import socket
import subprocess
import time
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[1]


def free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as connection:
        connection.bind(("127.0.0.1", 0))
        return connection.getsockname()[1]


class Peer:
    def __init__(self, engine, folder, index, port, role, manual_loading=False, fast_match=False, afk_match=False, exported=False, backend_url=""):
        self.output = folder / f"peer_{index}"
        self.command_id = 0
        self._last_status = None
        self.log = self.output.with_suffix(".log").open("w", encoding="utf-8")
        self.process = subprocess.Popen(
            [str(engine), "--headless", *([] if exported else ["--path", str(PROJECT)]),
             "--log-file", self.output.as_posix() + ".engine.log",
             *([] if exported else ["--script", "res://tests/network_peer.gd"]), "--",
             "--role", role, "--port", str(port), "--name", f"Player{index}",
             "--manual-loading", str(manual_loading).lower(),
             "--fast-match", str(fast_match).lower(), "--afk-match", str(afk_match).lower(),
             *(["--backend-url", backend_url] if backend_url else []),
             "--output", self.output.as_posix()],
            stdout=self.log, stderr=subprocess.STDOUT,
            cwd=engine.parent if exported else PROJECT,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )

    def status(self):
        if self.process.poll() is not None:
            raise AssertionError(f"Peer exited: {self.output}; inspect its log")
        try:
            self._last_status = json.loads(Path(str(self.output) + ".status.json").read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            pass
        return self._last_status

    def command(self, action, value=None):
        self.command_id += 1
        Path(str(self.output) + ".command.json").write_text(
            json.dumps({"id": self.command_id, "action": action, "value": value}),
            encoding="utf-8",
        )

    def stop(self):
        if self.process.poll() is None:
            self.command("exit")
            try:
                self.process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.process.terminate()
                self.process.wait(timeout=3)
        self.log.close()


def wait_for(peers, predicate, description, timeout=12):
    deadline = time.monotonic() + timeout
    states = []
    while time.monotonic() < deadline:
        states = [peer.status() for peer in peers]
        if all(states) and predicate(states):
            return states
        time.sleep(0.1)
    raise AssertionError(f"{description}: {states}")


def lobby_count(states, count):
    return all(len(state["room"]["players"]) == count
               and state["room"]["phase"] == 0 for state in states)


def playing(states, count, match_id):
    if not all(state["room"]["phase"] == 2 and state["room"]["match_id"] == match_id
               and state["markers"] == count and not state["lobby_visible"] for state in states):
        return False
    return all(state["room"] == states[0]["room"] for state in states)


def assert_unchanged(peers, phase, description):
    # 명령을 실제로 처리한 뒤 상태가 바뀌지 않았는지 확인한다.
    wait_for(peers, lambda states: all(state["command_id"] == peer.command_id
                                     for peer, state in zip(peers, states)), description)
    time.sleep(0.25)
    assert all(peer.status()["room"]["phase"] == phase for peer in peers), description


def run_room(engine, folder, count):
    port = free_port()
    peers = []
    owned = []
    try:
        host = Peer(engine, folder, 0, port, "host")
        peers.append(host)
        owned.append(host)
        wait_for([host], lambda states: lobby_count(states, 1), "host creation")
        host.command("ready", True)
        wait_for([host], lambda states: states[0]["room"]["players"][0]["ready"], "host readiness")
        host.command("start")
        assert_unchanged([host], 0, "one player cannot start")

        for index in range(1, count):
            client = Peer(engine, folder, index, port, "client")
            peers.append(client)
            owned.append(client)
        wait_for(peers, lambda states: lobby_count(states, count), "roster synchronization")
        peers[1].command("start")
        assert_unchanged(peers, 0, "client cannot start")
        host.command("start")
        assert_unchanged(peers, 0, "unready room cannot start")

        if count == 4:
            extra = Peer(engine, folder, 4, port, "client")
            peers.append(extra)
            owned.append(extra)
            wait_for([extra], lambda states: not states[0]["connecting"]
                     and states[0]["local_id"] == 0, "fifth player rejected")
            assert "가득" in extra.status()["message"]
            assert len(host.status()["room"]["players"]) == 4
            extra.stop()
            peers.pop()

        for peer in peers:
            peer.command("ready", True)
        wait_for(peers, lambda states: all(all(player["ready"] for player in state["room"]["players"])
                                          for state in states), "ready synchronization")
        peers[1].command("start")
        assert_unchanged(peers, 0, "ready client still cannot start")
        host.command("start")
        wait_for(peers, lambda states: playing(states, count, 1), "all loaded and same scene")
        peers[1].command("lobby")
        assert_unchanged(peers, 2, "client cannot return everyone to lobby")

        if count == 4:
            late = Peer(engine, folder, 5, port, "client")
            peers.append(late)
            owned.append(late)
            wait_for([late], lambda states: not states[0]["connecting"]
                     and states[0]["local_id"] == 0, "late join rejected")
            assert "진행" in late.status()["message"]
            late.stop()
            peers.pop()

        host.command("lobby")
        wait_for(peers, lambda states: lobby_count(states, count)
                 and all(state["markers"] == 0 and state["lobby_visible"]
                         and not any(player["ready"] for player in state["room"]["players"])
                         for state in states), "return and reset ready")
        peers[1].command("loaded", 1)
        assert_unchanged(peers, 0, "stale loaded acknowledgement ignored")
        for peer in peers:
            peer.command("ready", True)
        wait_for(peers, lambda states: all(all(player["ready"] for player in state["room"]["players"])
                                          for state in states), "second ready")
        host.command("start")
        wait_for(peers, lambda states: playing(states, count, 2), "second match starts")

        departing = peers.pop()
        departing.command("leave")
        wait_for([departing], lambda states: states[0]["local_id"] == 0
                 and states[0]["markers"] == 0, "client leaves")
        wait_for(peers, lambda states: all(len(state["room"]["players"]) == count - 1
                 and state["room"]["phase"] == 2 and state["markers"] == count - 1 for state in states),
                 "departure preserves game and removes character")
        if count == 2:
            wait_for(peers, lambda states: states[0]["match"]["phase"] == 6, "below two finishes match")
        else:
            assert peers[0].status()["match"]["phase"] != 6
        host.command("lobby")
        wait_for(peers, lambda states: lobby_count(states, count - 1), "host returns to lobby")
        departing.command("join")
        peers.append(departing)
        wait_for(peers, lambda states: lobby_count(states, count), "rejoin succeeds")
        seats = [player["seat"] for player in host.status()["room"]["players"]]
        assert len(set(seats)) == count, "seats must be unique"

        host.command("leave")
        wait_for(peers, lambda states: all(state["local_id"] == 0
                 and state["markers"] == 0 and not state["room"]["players"] for state in states),
                 "host departure cleans every client")
        host.command("host")
        wait_for([host], lambda states: lobby_count(states, 1), "host can create another room")
        print(f"PASS: {count} players, start gates, shared scene, rematch, leave/rejoin, host departure", flush=True)
    finally:
        for peer in owned:
            peer.stop()


def run_loading_barrier(engine, folder):
    port = free_port()
    peers = []
    try:
        host = Peer(engine, folder, 0, port, "host")
        peers.append(host)
        wait_for([host], lambda states: lobby_count(states, 1), "barrier host")
        client = Peer(engine, folder, 1, port, "client", manual_loading=True)
        peers.append(client)
        wait_for(peers, lambda states: lobby_count(states, 2), "barrier roster")
        for match_id in (1, 2):
            for peer in peers:
                peer.command("ready", True)
            wait_for(peers, lambda states: all(all(player["ready"] for player in state["room"]["players"])
                                              for state in states), "barrier ready")
            host.command("start")
            wait_for(peers, lambda states: all(state["room"]["phase"] == 1 for state in states)
                     and states[0]["room"]["players"][0]["loaded"], "wait for missing load ack")
            client.command("loaded", match_id - 1)
            assert_unchanged(peers, 1, "old match cannot release loading barrier")
            client.command("loaded", match_id)
            wait_for(peers, lambda states: all(state["room"]["phase"] == 2 for state in states),
                     "correct acknowledgement releases barrier")
            client.command("loaded", match_id)
            assert_unchanged(peers, 2, "duplicate load acknowledgement is harmless")
            host.command("lobby")
            wait_for(peers, lambda states: lobby_count(states, 2), "barrier reset")

        for peer in peers:
            peer.command("ready", True)
        wait_for(peers, lambda states: all(all(player["ready"] for player in state["room"]["players"])
                                          for state in states), "timeout ready")
        host.command("start")
        wait_for(peers, lambda states: all(state["room"]["phase"] == 1 for state in states), "timeout loading")
        wait_for(peers, lambda states: lobby_count(states, 2), "loading timeout recovers room")
        print("PASS: loading barrier, stale/duplicate acknowledgements, loading timeout recovery", flush=True)
    finally:
        for peer in peers:
            peer.stop()


def run_connection_failure(engine, folder):
    peer = Peer(engine, folder, 0, free_port(), "client")
    try:
        ss = wait_for([peer], lambda ss: ss[0]["command_id"] == 0 and not ss[0]["connecting"]
                      and ss[0]["local_id"] == 0 and ("실패" in ss[0]["message"] or "초과" in ss[0]["message"]),
                      "unreachable host shows failure", timeout=12)
        assert ss[0]["lobby_visible"]
        print("PASS: unreachable host reports connection failure and stays at menu", flush=True)
    finally:
        peer.stop()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    args = parser.parse_args()
    results = PROJECT / ".godot" / "network_tests" / str(time.time_ns())
    results.mkdir(parents=True)
    for count in (2, 3, 4):
        folder = results / str(count)
        folder.mkdir()
        run_room(args.godot, folder, count)
    barrier_folder = results / "loading"
    barrier_folder.mkdir()
    run_loading_barrier(args.godot, barrier_folder)
    failure_folder = results / "failure"
    failure_folder.mkdir()
    run_connection_failure(args.godot, failure_folder)
    for path in results.rglob("*.log"):
        content = path.read_text(encoding="utf-8")
        errors = [line for line in content.splitlines()
                  if ("ERROR:" in line or "SCRIPT ERROR:" in line)
                  and "Failed to read the root certificate store" not in line]
        assert not errors, f"Unexpected engine errors in {path}: {errors}"
    print(f"All checks passed. Logs: {results}", flush=True)


if __name__ == "__main__":
    main()
