"""실제 ENet 3프로세스: 초대/암호/정원/착석/호스트 권한/카드 턴/재준비 검증."""
import argparse,time
from pathlib import Path
from run_multiplayer import Peer,free_port,wait_for,PROJECT

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--godot',type=Path,required=True);args=parser.parse_args()
    output=PROJECT/'.godot'/'lounge_network'/str(time.time_ns());output.mkdir(parents=True)
    port=free_port();peers=[]
    try:
        host=Peer(args.godot,output,0,port,'social_host');peers.append(host)
        hs=wait_for([host],lambda ss:len(ss[0]['room']['players'])==1 and ss[0]['markers']==1,'host in map')[0]
        code=hs['room']['room_code']
        client=Peer(args.godot,output,1,port,'client');peers.append(client)
        wait_for([client],lambda ss:not ss[0]['connecting'] and ss[0]['local_id']==0 and '코드' in ss[0]['message'],'missing invite rejected')
        client.command('secure_join',['WRONG','test-password'])
        wait_for([client],lambda ss:ss[0]['command_id']>=1 and not ss[0]['connecting'] and '코드' in ss[0]['message'],'wrong invite rejected')
        client.command('secure_join',[code,'bad'])
        wait_for([client],lambda ss:ss[0]['command_id']>=2 and not ss[0]['connecting'] and '비밀번호' in ss[0]['message'],'wrong password rejected')
        client.command('secure_join',[code,'test-password'])
        states=wait_for(peers,lambda ss:all(len(s['room']['players'])==2 and s['markers']==2 and s['room']['phase']==0 for s in ss),'authenticated joins visible in waiting map')
        client_id=states[1]['local_id']
        assert states[0]['room']==states[1]['room']
        assert not any('password' in key and key!='has_password' for key in states[1]['room'])
        third=Peer(args.godot,output,2,port,'client');peers.append(third)
        wait_for([third],lambda ss:not ss[0]['connecting'] and ss[0]['local_id']==0,'third challenge')
        third.command('secure_join',[code,'test-password'])
        wait_for([third],lambda ss:ss[0]['command_id']>=1 and not ss[0]['connecting'] and '가득' in ss[0]['message'],'capacity two enforced')
        rules=states[0]['room']['settings'].copy();rules['rounds']=19;rules['hit_stun']=3.0
        client.command('raw_settings',rules)
        wait_for([client],lambda ss:ss[0]['command_id']>=4,'forged settings sent');time.sleep(.2)
        assert host.status()['room']['settings']['rounds']==5
        host.command('ready',True);client.command('ready',True)
        time.sleep(.35)
        assert host.status()['room']['phase']==0 and all(not p['ready'] for p in host.status()['room']['players'])
        host.command('seat');client.command('seat')
        wait_for([host,client],lambda ss:all(all(p['seated'] for p in s['poses']) for s in ss),'both seated')
        host.command('ready',True)
        wait_for([host,client],lambda ss:all(s['room']['players'][0]['ready'] for s in ss),'host ready visible')
        rules['rounds']=6;host.command('settings',rules)
        wait_for([host,client],lambda ss:all(s['room']['settings']['rounds']==6 and all(not p['ready'] for p in s['room']['players']) for s in ss),'rules update resets ready')
        assert host.status()['room']['settings']['hit_stun']==1.0
        host.command('ready',True);client.command('ready',True)
        states=wait_for([host,client],lambda ss:all(s['room']['phase']==2 and s['match']['phase']==5 and s['match']['card_peer']==1 for s in ss),'all ready loads card turn')
        # 현재 손패/턴을 다시 시작하지 않고 다음 카드 턴·다트 턴부터 시간을 적용한다.
        live=states[0]['room']['settings'].copy()
        original_theme=live['theme_id']
        live.update(rounds=2,dart_seconds=15.0,card_seconds=12.0,special_chance=85.0,theme_id=1-original_theme)
        host.command('settings',live)
        states=wait_for([host,client],lambda ss:all(s['room']['settings']['rounds']==2 and s['room']['settings']['card_seconds']==12 for s in ss),'live rules replicated')
        assert all(s['room']['settings']['theme_id']==original_theme and s['room']['settings']['special_chance']==85 and s['match']['card_peer']==1 for s in states)
        client.command('card',['select',0]);time.sleep(.25)
        assert all(p['pending_card']==-1 for p in host.status()['match']['players'])
        host.command('card',['select',0]);time.sleep(1.5);host.command('card',['use',0])
        states=wait_for([host,client],lambda ss:all(s['match']['card_peer']==client_id and len(s['match']['players'][0]['hand'])==6 for s in ss),'host card use replicated')
        assert all(0<s['remaining']<=12.5 for s in states)
        client.command('card',['select',0]);time.sleep(1.5);client.command('card',['use',0])
        states=wait_for([host,client],lambda ss:all(s['match']['phase']==2 and len(s['match']['players'][1]['hand'])==6 for s in ss),'remote card use advances darts')
        assert states[0]['match']['players']==states[1]['match']['players']
        assert all(10<s['remaining']<=15.5 for s in states)
        host.command('lobby')
        wait_for([host,client],lambda ss:all(s['room']['phase']==0 and s['match']['phase']==0 and all(not p['ready'] for p in s['room']['players']) for s in ss),'back to map and re-ready')
        print('PASS: invite/password/capacity, host-only settings, seated readiness, setting consent reset, real remote card use, map return',flush=True)
    finally:
        for peer in peers:peer.stop()
    for path in output.glob('*.log'):
        errors=[line for line in path.read_text(encoding='utf-8').splitlines() if ('ERROR:' in line or 'SCRIPT ERROR:' in line) and 'root certificate store' not in line]
        assert not errors,(path,errors[:10])
    print('All lounge checks passed. Logs:',output,flush=True)
if __name__=='__main__':main()
