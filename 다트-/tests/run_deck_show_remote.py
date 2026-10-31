"""멀티(실제 ENet 2프로세스)에서 카드 충전 라운드 덱 섞기·나눠 주기 연출이 손님 화면에서도 도는지 본다(2026-10-31 늦은 밤).

방장 = 화면 없음(social_host), 손님 = 창 모드(화면이 있어야 연출 노드가 생긴다).
1라운드 첫 나눠 주기(7장씩) → 다트 턴에 둘 다 카드 한 장씩 쓰기 → 2라운드 충전(한 장씩)에서 다시 도는지 확인한다.
화면: .godot/deck_show_remote/<시각>/peer_1_cards1.png · peer_1_cards2.png
    python tests/run_deck_show_remote.py --godot <Godot 실행 파일>
"""
import argparse, subprocess, time
from pathlib import Path
from run_multiplayer import Peer, free_port, wait_for, PROJECT


class WindowedPeer(Peer):
    """Peer 와 같지만 --headless 없이 창으로 띄운다(덱 연출·매트 카드는 화면이 있을 때만 만든다)."""

    def __init__(self, engine, folder, index, port, role):
        self.output = folder / f"peer_{index}"
        self.command_id = 0
        self._last_status = None
        self.log = self.output.with_suffix(".log").open("w", encoding="utf-8")
        self.process = subprocess.Popen(
            [str(engine), "--path", str(PROJECT), "--resolution", "1280x720",
             "--log-file", self.output.as_posix() + ".engine.log",
             "--script", "res://tests/network_peer.gd", "--",
             "--role", role, "--port", str(port), "--name", f"Player{index}",
             "--manual-loading", "false", "--fast-match", "false", "--afk-match", "false",
             "--output", self.output.as_posix()],
            stdout=self.log, stderr=subprocess.STDOUT, cwd=PROJECT)


def deck(state):
    return state.get('deck_show', {'played': 0, 'playing': False, 'hidden': 0})


def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--godot', type=Path, required=True); args = parser.parse_args()
    output = PROJECT / '.godot' / 'deck_show_remote' / str(time.time_ns()); output.mkdir(parents=True)
    port = free_port(); peers = []
    try:
        host = Peer(args.godot, output, 0, port, 'social_host'); peers.append(host)
        hs = wait_for([host], lambda ss: len(ss[0]['room']['players']) == 1 and ss[0]['markers'] == 1, 'host in map')[0]
        code = hs['room']['room_code']
        client = WindowedPeer(args.godot, output, 1, port, 'client'); peers.append(client)
        wait_for([client], lambda ss: not ss[0]['connecting'] and ss[0]['local_id'] == 0, 'client challenge', timeout=30)
        client.command('secure_join', [code, 'test-password'])
        wait_for([host, client], lambda ss: all(len(s['room']['players']) == 2 and s['markers'] == 2 for s in ss), 'client joined', timeout=30)
        rules = host.status()['room']['settings'].copy(); rules.update(rounds=2, dart_seconds=5.0)
        host.command('settings', rules)
        wait_for([host, client], lambda ss: all(s['room']['settings']['rounds'] == 2 for s in ss), 'rules replicated')
        host.command('seat'); client.command('seat')
        wait_for([host, client], lambda ss: all(all(p['seated'] for p in s['poses']) for s in ss), 'both seated')
        host.command('ready', True); client.command('ready', True)
        # 1라운드 카드 단계: 손님 화면에서 덱 연출이 시작되고 새 카드가 매트에서 잠깐 숨는다.
        states = wait_for([client], lambda ss: ss[0].get('match', {}).get('phase') == 5 and deck(ss[0])['played'] >= 1, 'round 1 deck show on client', timeout=40)
        assert deck(states[0])['playing'] and deck(states[0])['hidden'] > 0, deck(states[0])
        time.sleep(1.0); client.command('shot', 'cards1')
        states = wait_for([host, client], lambda ss: all(s['match']['phase'] == 2 for s in ss), 'darts begin', timeout=10)
        time.sleep(0.3)
        assert deck(client.status())['hidden'] == 0 and not deck(client.status())['playing'], deck(client.status())
        # 다트 턴에 둘 다 카드 한 장씩 쓴다 → 다음 라운드에 한 장씩만 다시 받는다.
        host.command('card', ['select', 0]); time.sleep(1.5); host.command('card', ['use', 1])
        client.command('card', ['select', 0]); time.sleep(1.5); client.command('card', ['use', 1])
        wait_for([host], lambda ss: all(len(p['hand']) == 6 for p in ss[0]['match']['players']), 'both used a card', timeout=10)
        states = wait_for([client], lambda ss: ss[0]['match']['round'] == 2 and ss[0]['match']['phase'] == 5 and deck(ss[0])['played'] >= 2,
                          'round 2 refill deck show on client', timeout=60)
        time.sleep(0.8); client.command('shot', 'cards2')
        wait_for([host, client], lambda ss: all(s['match']['phase'] == 2 and s['match']['round'] == 2 for s in ss), 'round 2 darts', timeout=10)
        time.sleep(0.3)
        final = client.status()
        assert deck(final)['hidden'] == 0, deck(final)
        assert all(len(p['hand']) == 7 for p in final['match']['players']), final['match']['players']
        print('PASS: remote client plays deck shuffle + deal on first deal and on refill; mat cards all shown when darts start', flush=True)
    finally:
        for peer in peers: peer.stop()
    for path in output.glob('*.log'):
        errors = [line for line in path.read_text(encoding='utf-8').splitlines() if ('ERROR:' in line or 'SCRIPT ERROR:' in line) and 'root certificate store' not in line]
        assert not errors, (path, errors[:10])
    print('Deck show remote check passed. Logs:', output, flush=True)


if __name__ == '__main__': main()
