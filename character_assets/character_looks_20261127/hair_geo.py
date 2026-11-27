"""[캐릭터 3안 v2 · 2026-11-27] 승인 캐릭터 머리 다듬기 + 새 머리 모양 + 입체 눈썹 생성(쉬는 자세 모델 좌표, m).
입력: mesh.json(zz_export_head.gd)   출력: geo.json(zz_convert_geo.gd 가 character_look_data.res 로 바꾼다)
정면 = -Z, 캐릭터 오른쪽 = +X.  방위각 az: 0 = 앞, +90 = 캐릭터 오른쪽.  고도 el: +90 = 정수리.

v1 과 달라진 점(사용자 피드백 "너무 이질적 · 눈썹이 눈 안쪽에 박혀 있다"):
  1) 두피: 옛 곱슬머리를 작은 타원체로 누르던 것을 버리고, 머리카락이 아닌 살 정점(이마·옆머리·뒤통수 아래)에서
     매끈하게 이어 채운 "두피 지도"로 누른다 → 이마 위가 7 cm 움푹 꺼지던 것이 사라지고, 새 머리가 두피에 붙는다.
     귀는 두피 지도에서 빼서 새 머리 밖으로 귀가 나온다.
  2) 머리 모양을 캐릭터마다 실루엣부터 다르게: 준 = 짧은 옆머리 + 위로 세운 삐죽 앞머리 · 솜 = 턱선 단발 + 옆으로 넘긴 앞머리
     · 온 = 옆을 짧게 민 페이드 + 정수리 곱슬 덩어리.
  3) 눈썹을 그림이 아니라 입체 조각으로 이마 앞에 붙인다(튀어나온 눈알보다 앞). 그림 눈썹은 셰이더가 살색으로 지운다.
"""
import json, sys, math
import numpy as np

HERE = sys.argv[1] if len(sys.argv) > 1 else '.'
d = json.load(open(f'{HERE}/mesh.json'))
head = d['Body']['surfaces'][2]
P = np.array(head['pos'], dtype=np.float64)
C = np.array(head['col'], dtype=np.float64)


def smooth(e0, e1, x):
    t = np.clip((np.asarray(x, float) - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


# ---------- 1. 머리카락 정점 분류(텍스처 색) ----------
V = C.max(1)
is_hair_col = (V < 0.5) & (C[:, 0] - C[:, 2] > 0.05)
# 얼굴 앞(눈썹·입술선·눈동자)은 머리카락이 아니다
face_zone = (P[:, 2] < -0.13) & (P[:, 1] < 1.675) & (np.abs(P[:, 0]) < 0.108)
hair = is_hair_col & ~face_zone
key = np.round(P / 1e-5).astype(np.int64)
_, inv = np.unique(key, axis=0, return_inverse=True)
inv = inv.reshape(-1)
grp = np.zeros(inv.max() + 1, bool)
np.logical_or.at(grp, inv, hair)
hair = grp[inv]
# 귀(두피 지도에서 뺀다 → 새 머리 밖으로 나온다)
ear = (np.abs(P[:, 0]) > 0.128) & (P[:, 1] > 1.50) & (P[:, 1] < 1.645) & (P[:, 2] > -0.115) & (P[:, 2] < 0.065) & ~hair

# ---------- 2. 두피 지도 ----------
HC = np.array([0.0, 1.60, -0.06])
AZ_STEP, EL_STEP = 4.0, 4.0
AZS = np.arange(-180, 180, AZ_STEP)
ELS = np.arange(-60, 90.01, EL_STEP)


def to_dir(az, el):
    az = np.radians(az); el = np.radians(el)
    return np.stack([np.sin(az) * np.cos(el), np.sin(el), -np.cos(az) * np.cos(el)], axis=-1)


def polar(points):
    rel = points - HC
    r = np.linalg.norm(rel, axis=1)
    az = np.degrees(np.arctan2(rel[:, 0], -rel[:, 2]))
    el = np.degrees(np.arcsin(np.clip(rel[:, 1] / r, -1, 1)))
    return r, az, el


r0, az0, el0 = polar(P)
ia = ((az0 + 180) / AZ_STEP).astype(int) % len(AZS)
ie = np.clip(np.round((el0 - ELS[0]) / EL_STEP).astype(int), 0, len(ELS) - 1)
known = np.full((len(ELS), len(AZS)), np.nan)
cnt_skin = np.zeros(known.shape, int)
cnt_hair = np.zeros(known.shape, int)
for a, e, rr, h, er in zip(ia, ie, r0, hair, ear):
    if er:
        continue
    if h:
        cnt_hair[e, a] += 1
    else:
        cnt_skin[e, a] += 1
        if np.isnan(known[e, a]) or rr > known[e, a]:
            known[e, a] = rr
# 살 정점이 조금만 섞인 칸(곱슬 사이 밝은 칸)은 믿지 않는다
trust = (cnt_skin >= 3) & (cnt_hair < cnt_skin)
known[~trust] = np.nan
# 빈 칸 = 이웃 평균으로 여러 번 채운다(라플라스 채우기). 위쪽 끝(정수리) 줄은 한 점으로 모인다.
grid = known.copy()
fill = np.isnan(grid)
grid[fill] = np.nanmean(known)
for _ in range(400):
    pad = np.pad(grid, ((1, 1), (0, 0)), mode='edge')
    avg = (np.roll(grid, 1, 1) + np.roll(grid, -1, 1) + pad[:-2] + pad[2:]) / 4
    grid[fill] = avg[fill]
    grid[-1, :] = grid[-1, :].mean()
RG = grid


def head_r(az, el):
    """방향별 두피 반지름(쌍선형 보간)."""
    az = np.asarray(az, float); el = np.asarray(el, float)
    fa = (az + 180) / AZ_STEP
    fe = np.clip((el - ELS[0]) / EL_STEP, 0, len(ELS) - 1.0001)
    a0 = np.floor(fa).astype(int); e0 = np.floor(fe).astype(int)
    ta = fa - a0; te = fe - e0
    a0 %= len(AZS); a1 = (a0 + 1) % len(AZS); e1 = np.minimum(e0 + 1, len(ELS) - 1)
    return (RG[e0, a0] * (1 - ta) * (1 - te) + RG[e0, a1] * ta * (1 - te) +
            RG[e1, a0] * (1 - ta) * te + RG[e1, a1] * ta * te)


# ---------- 3. 옛 곱슬머리를 두피 안으로 ----------
NP = P.copy()
target = np.minimum(r0, head_r(az0, el0) - 0.003)
dirs = (P - HC) / r0[:, None]
NP[hair] = HC + dirs[hair] * target[hair, None]
moved = np.where(np.linalg.norm(NP - P, axis=1) > 1e-6)[0]


# ---------- 4. 머리 껍데기 ----------
def el_at_height(az, y_target):
    lo = np.full(np.shape(az), -60.0); hi = np.full(np.shape(az), 89.0)
    for _ in range(40):
        mid = (lo + hi) / 2
        y = HC[1] + np.sin(np.radians(mid)) * head_r(az, mid)
        below = y < y_target
        lo = np.where(below, mid, lo); hi = np.where(below, hi, mid)
    return (lo + hi) / 2


def periodic_interp(points):
    """[(az, 값)] 제어점 → az 배열을 받는 매끈한 함수(주기 360°, 코사인 보간)."""
    pts = sorted(points)
    xs = np.array([p[0] for p in pts], float); ys = np.array([p[1] for p in pts], float)
    xs = np.concatenate([xs - 360, xs, xs + 360]); ys = np.concatenate([ys, ys, ys])

    def f(az):
        az = (np.asarray(az, float) + 180) % 360 - 180
        i = np.clip(np.searchsorted(xs, az) - 1, 0, len(xs) - 2)
        t = (az - xs[i]) / (xs[i + 1] - xs[i])
        t = (1 - np.cos(t * np.pi)) / 2
        return ys[i] * (1 - t) + ys[i + 1] * t
    return f


def shell(lim_fn, thick_fn, n_az=40, n_rows=10, gamma=1.0, tuck_deg=5.0, cap_el=84.0, post=None, jitter=0.0, seed=1):
    """이마선 lim_fn(az)=높이(m)부터 정수리까지 줄을 나눈 껍데기. 첫 줄 아래 한 줄은 머리 속으로 접어 넣는다."""
    rng = np.random.default_rng(seed)
    az = np.arange(n_az) * 360.0 / n_az - 180.0
    el_h = el_at_height(az, lim_fn(az))
    rows = [el_h - tuck_deg]
    for k in range(n_rows):
        f = (k / (n_rows - 1)) ** gamma
        rows.append(el_h + (cap_el - el_h) * f)
    E = np.array(rows)
    A = np.tile(az, (E.shape[0], 1))
    cov = np.ones(E.shape, bool); cov[0] = False
    base = head_r(A, E)
    rad = np.where(cov, base + thick_fn(A, E), base - 0.006)
    rad = rad + np.where(cov, rng.uniform(-jitter, jitter, rad.shape), 0.0)
    pts = HC + to_dir(A, E) * rad[..., None]
    top = HC + np.array([0, 1.0, 0]) * (float(head_r(0.0, 90.0)) + float(thick_fn(np.array(0.0), np.array(90.0))))
    if post is not None:
        pts = post(pts, A, E, cov)
        top = post(top[None, None, :], np.zeros((1, 1)), np.full((1, 1), 90.0), np.ones((1, 1), bool))[0, 0]
    verts = pts.reshape(-1, 3).tolist()
    nr, na = E.shape
    idx = lambda i, j: i * na + (j % na)
    tris = []
    for i in range(nr - 1):
        for j in range(na):
            q = [idx(i, j), idx(i, j + 1), idx(i + 1, j + 1), idx(i + 1, j)]
            if (i + j) % 2 == 0:
                tris += [[q[0], q[2], q[1]], [q[0], q[3], q[2]]]
            else:
                tris += [[q[0], q[3], q[1]], [q[1], q[3], q[2]]]
    top_i = len(verts); verts.append(list(top))
    for j in range(na):
        tris.append([idx(nr - 1, j), top_i, idx(nr - 1, j + 1)])
    return np.array(verts), tris


def gauss(az, el, az0, el0, saz, sel):
    da = (az - az0 + 180) % 360 - 180
    return np.exp(-0.5 * ((da / saz) ** 2 + ((el - el0) / sel) ** 2))


def surface_point(az, el, thick):
    return HC + to_dir(az, el) * (head_r(az, el) + thick)


def tuft(az, el, length, radius_deg, sweep, thick_fn, n=5, twist=0.0, sink=0.004):
    """삐죽한 머리 다발(낮은 다각뿔). 밑면 n 점을 껍데기 표면 조금 안쪽에, 끝을 sweep 쪽으로 뺀다."""
    center = surface_point(az, el, float(thick_fn(np.array(az), np.array(el))) - sink)
    normal = to_dir(az, el)
    base = []
    for k in range(n):
        ang = 2 * np.pi * k / n + twist
        a_ = az + radius_deg * np.cos(ang) / max(np.cos(np.radians(el)), 0.25)
        e_ = el + radius_deg * np.sin(ang)
        base.append(surface_point(a_, e_, float(thick_fn(np.array(a_), np.array(e_))) - sink))
    direction = normal * 0.55 + np.asarray(sweep, float)
    direction /= np.linalg.norm(direction)
    apex = center + direction * length
    V_ = np.array(base + [apex])
    T_ = [[k, (k + 1) % n, n] for k in range(n)]
    return V_, T_, center


def ico_blob(center, radii, subdiv=1, jitter=0.08, seed=3, rot_y=0.0):
    t = (1 + 5 ** 0.5) / 2
    v = [[-1, t, 0], [1, t, 0], [-1, -t, 0], [1, -t, 0], [0, -1, t], [0, 1, t], [0, -1, -t], [0, 1, -t],
         [t, 0, -1], [t, 0, 1], [-t, 0, -1], [-t, 0, 1]]
    f = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6],
         [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10],
         [8, 6, 7], [9, 8, 1]]
    v = [np.array(x, float) / np.linalg.norm(x) for x in v]
    for _ in range(subdiv):
        cache = {}; nf = []

        def mid(a, b):
            k = (min(a, b), max(a, b))
            if k not in cache:
                m = v[a] + v[b]; v.append(m / np.linalg.norm(m)); cache[k] = len(v) - 1
            return cache[k]
        for a, b, c in f:
            ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
            nf += [[a, ab, ca], [b, bc, ab], [c, ca, bc], [ab, bc, ca]]
        f = nf
    rng = np.random.default_rng(seed)
    V_ = np.array(v) * (1 + rng.uniform(-jitter, jitter, (len(v), 1)))
    V_ = V_ * np.array(radii)
    cy, sy = math.cos(rot_y), math.sin(rot_y)
    R = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    V_ = V_ @ R.T + np.array(center)
    return V_, np.array(f)


def godot_winding(verts, tris, center):
    """삼각형 법선이 center 에서 바깥을 보도록 맞춘 뒤, Godot 앞면(시계) 순서로 돌려준다."""
    out = []
    for a, b, c in tris:
        n = np.cross(verts[b] - verts[a], verts[c] - verts[a])
        m = (verts[a] + verts[b] + verts[c]) / 3 - center
        out.append([int(a), int(c), int(b)] if np.dot(n, m) > 0 else [int(a), int(b), int(c)])
    return out


def tuft_winding(verts, tris, base_center):
    out = []
    for a, b, c in tris:
        n = np.cross(verts[b] - verts[a], verts[c] - verts[a])
        m = (verts[a] + verts[b] + verts[c]) / 3 - base_center
        out.append([int(a), int(c), int(b)] if np.dot(n, m) > 0 else [int(a), int(b), int(c)])
    return out


def pack(parts):
    return [{'v': np.round(np.asarray(v_), 5).tolist(), 't': np.asarray(t_).tolist(), 'c': c_} for v_, t_, c_ in parts]


def merge(pieces):
    """[(verts, tris)] → 한 덩어리(한 조각 = 한 뼈라 묶어도 된다)."""
    V_ = []; T_ = []
    for v_, t_ in pieces:
        b = len(V_)
        V_ += [list(p) for p in np.asarray(v_)]
        T_ += [[a + b, c + b, e + b] for a, c, e in t_]
    return np.array(V_), T_


styles = {}

# ── 준: 짧게 친 옆·뒷머리 + 위로 세워 앞으로 쏠린 삐죽 다발(정비사의 부스스한 머리) ──
jun_lim = periodic_interp([(0, 1.694), (25, 1.690), (40, 1.672), (62, 1.640), (75, 1.585), (88, 1.600),
                           (100, 1.625), (118, 1.560), (140, 1.500), (180, 1.468),
                           (-25, 1.692), (-40, 1.674), (-62, 1.640), (-75, 1.585), (-88, 1.600),
                           (-100, 1.625), (-118, 1.560), (-140, 1.500)])


def jun_thick(A, E):
    aa = np.abs((A + 180) % 360 - 180)
    side = 0.0045
    top = 0.016 * smooth(18, 48, E)
    front = 0.010 * gauss(A, E, 0, 32, 40, 12)
    back = 0.004 * smooth(120, 170, aa) * smooth(-20, 20, E)
    return side + top + front + back


v, t = shell(jun_lim, jun_thick, n_az=40, n_rows=10, gamma=1.0, jitter=0.0012, seed=11)
pieces = [(v, godot_winding(v, t, HC))]
# 다발: (방위, 고도, 길이, 밑 반지름°, 쏠림 방향) — 앞쪽은 앞·위로, 정수리는 위·뒤로, 오른쪽으로 조금 쏠린다.
FWD = np.array([0, 0.25, -1.0]); UPB = np.array([0.15, 1.0, 0.35]); RIGHT = np.array([0.6, 0.4, -0.2])
for az_, el_, ln, rad_, sw, tw in [
        (-28, 38, 0.050, 13, FWD + [0.35, 0.1, 0], 0.2), (-6, 42, 0.058, 14, FWD + [0.25, 0.25, 0], 0.7),
        (18, 40, 0.052, 13, FWD + [0.45, 0.2, 0], 1.1), (40, 36, 0.040, 12, RIGHT + [0, 0, -0.3], 0.4),
        (-45, 46, 0.036, 12, FWD + [0.1, 0.5, 0.2], 0.9), (-18, 58, 0.050, 14, UPB + [0.2, 0, -0.6], 0.3),
        (12, 60, 0.054, 14, UPB + [0.35, 0, -0.5], 1.3), (38, 56, 0.044, 13, RIGHT + UPB * 0.5, 0.6),
        (-40, 64, 0.040, 13, UPB, 1.0), (0, 74, 0.046, 14, UPB + [0.2, 0, 0.2], 0.5),
        (60, 50, 0.030, 11, RIGHT + [0, 0.3, 0.3], 0.8), (-62, 52, 0.026, 11, UPB + [-0.4, 0, 0.3], 0.2),
        (150, 62, 0.030, 14, UPB + [0, 0, 0.6], 0.4), (-150, 64, 0.028, 14, UPB + [0, 0, 0.6], 1.2),
        (100, 64, 0.030, 13, UPB + [0.4, 0, 0.3], 0.9), (-100, 66, 0.028, 13, UPB + [-0.3, 0, 0.3], 0.1)]:
    tv, tt, tc = tuft(az_, el_, ln, rad_, sw, jun_thick, n=5, twist=tw)
    pieces.append((tv, tuft_winding(tv, tt, tc)))
jv, jt = merge(pieces)
# 키 180 cm 규칙(온과 같다): 1.775 m 위의 다발 끝은 절반으로 눌러 1.80 m 를 넘지 않게.
_hi = jv[:, 1] > 1.775
jv[_hi, 1] = 1.775 + (jv[_hi, 1] - 1.775) * 0.5
jv[:, 1] = np.minimum(jv[:, 1], 1.800)
styles['jun'] = pack([(jv, jt, 'hair')])


# ── 솜: 턱선 단발(옆·뒤가 곧게 떨어지고 끝이 가닥으로 들쭉날쭉) + 캐릭터 왼쪽 가르마에서 오른쪽으로 넘긴 앞머리 ──
SOM_NAZ = 44
_som_base = periodic_interp([(-48, 1.706), (-30, 1.692), (-10, 1.677), (10, 1.665), (28, 1.658), (42, 1.664),
                             (52, 1.585), (60, 1.470), (90, 1.442), (135, 1.436), (180, 1.434),
                             (-58, 1.640), (-66, 1.468), (-90, 1.442), (-135, 1.436)])


def som_lim(az):
    """끝단은 기둥(방위)마다 0.7 cm 씩 번갈아 올리고 내려 가닥 끝처럼 보이게 한다(얼굴 옆·뒤만)."""
    az = np.asarray(az, float)
    j = np.round((az + 180) / (360.0 / SOM_NAZ))
    jag = 0.007 * np.cos(np.pi * j) * smooth(56, 66, np.abs(az))
    return _som_base(az) + jag


def som_thick(A, E):
    aa = np.abs((A + 180) % 360 - 180)
    base = 0.006 + 0.004 * smooth(10, 50, E)
    bangs = 0.008 * gauss(A, E, 15, 26, 34, 9)                    # 앞머리 두께(오른쪽으로 쏠림)
    part = -0.004 * gauss(A, E, -42, 60, 5, 22)                    # 가르마 홈
    sides = 0.004 * smooth(50, 80, aa) * (1 - smooth(10, 40, E))  # 옆 볼륨
    return np.maximum(base + bangs + part + sides, 0.0045)


# 귀 둘레(방위 4°마다 HC 에서 잰 가로 거리 최댓값) — 단발이 귀를 덮게(귀는 두피 지도에서 빠져 있어 그대로면 머리를 뚫는다).
_ear_rel = P[ear] - HC
_ear_az = np.degrees(np.arctan2(_ear_rel[:, 0], -_ear_rel[:, 2]))
_ear_hor = np.hypot(_ear_rel[:, 0], _ear_rel[:, 2])
EAR_R = np.zeros(90)
for a_, h_ in zip(((_ear_az + 180) / 4).astype(int) % 90, _ear_hor):
    EAR_R[a_] = max(EAR_R[a_], h_)
EAR_R = np.maximum(EAR_R, np.maximum(np.roll(EAR_R, 1), np.roll(EAR_R, -1)))   # 한 칸씩 넓혀 여유


def som_hang(pts, A, E, cov):
    """옆·뒤 머리는 수직으로 떨어진다(목·턱을 따라 안으로 감기지 않게). 끝은 조금 안으로 말린다."""
    p = pts.copy()
    aa = np.abs((A + 180) % 360 - 180)
    rel = p - HC
    hor = np.hypot(rel[..., 0], rel[..., 2])
    eq = head_r(A, np.zeros_like(E)) + 0.013 + 0.004 * smooth(60, 120, aa)   # 귀 높이 둘레 + 얇은 볼륨
    want = eq - 0.010 * smooth(1.49, 1.44, p[..., 1])                     # 끝은 1 cm 안으로
    # 가닥 결: 기둥마다 3 mm 씩 번갈아 들고 나게(매끈한 헬멧처럼 보이지 않게)
    j = np.round((A + 180) / (360.0 / SOM_NAZ))
    want = want + 0.003 * np.cos(np.pi * j) * smooth(70, 90, aa)
    k = smooth(54, 66, aa) * smooth(12, -6, E)                            # 얼굴 옆·뒤 · 귀 높이 아래
    new_hor = np.where(cov, np.maximum(hor, hor + (want - hor) * k), hor)
    # 귀 높이(1.48~1.67 m)에서는 귀 둘레보다 8 mm 밖으로.
    ear_r = EAR_R[((A + 180) / 4).astype(int) % 90]
    ear_band = smooth(1.47, 1.50, p[..., 1]) * smooth(1.68, 1.655, p[..., 1])
    new_hor = np.where(cov & (ear_r > 0), np.maximum(new_hor, (ear_r + 0.008) * ear_band + new_hor * (1 - ear_band)), new_hor)
    scale = np.where(hor > 1e-6, new_hor / np.maximum(hor, 1e-6), 1.0)
    p[..., 0] = HC[0] + rel[..., 0] * scale
    p[..., 2] = HC[2] + rel[..., 2] * scale
    return p


v, t = shell(som_lim, som_thick, n_az=SOM_NAZ, n_rows=11, gamma=1.1, post=som_hang, jitter=0.0008, seed=21)
styles['som'] = pack([(v, godot_winding(v, t, HC), 'hair')])


# ── 온: 옆·뒤를 짧게 민 페이드(짙은 색 얇은 껍데기) + 정수리 곱슬 덩어리(키 180 cm 를 넘지 않게) ──
ON_TOP = 1.800
on_lim = periodic_interp([(0, 1.700), (22, 1.698), (42, 1.676), (62, 1.640), (75, 1.598), (90, 1.615),
                          (102, 1.630), (122, 1.545), (145, 1.490), (180, 1.470),
                          (-22, 1.698), (-42, 1.676), (-62, 1.640), (-75, 1.598), (-90, 1.615),
                          (-102, 1.630), (-122, 1.545), (-145, 1.490)])
v, t = shell(on_lim, lambda A, E: 0.003 + 0.0 * A, n_az=40, n_rows=10, gamma=1.0, seed=31)
fade = (v, godot_winding(v, t, HC))
# 정수리 덩어리: 이마선 조금 위에서 시작하는 두툼한 껍데기 + 그 위 작은 곱슬 덩이들(촘촘히 박아 하나의 덩어리로 읽히게)
on_top_lim = periodic_interp([(0, 1.704), (40, 1.700), (90, 1.692), (140, 1.684), (180, 1.680),
                              (-40, 1.700), (-90, 1.692), (-140, 1.684)])


def on_top_thick(A, E):
    # 가장자리는 얇게(페이드에서 자라 올라오듯) → 정수리로 갈수록 두툼하게
    return 0.004 + 0.026 * smooth(40, 72, E)


v, t = shell(on_top_lim, on_top_thick, n_az=36, n_rows=8, gamma=1.0, tuck_deg=4.0, seed=32)
pieces = [(v, godot_winding(v, t, HC))]
rng = np.random.default_rng(7)
for el_, ring in [(52, 14), (61, 12), (70, 10), (78, 7), (85, 4), (89, 1)]:
    off = rng.uniform(0, 360)
    for k in range(ring):
        az_ = off + 360.0 * k / ring + rng.uniform(-6, 6)
        az_ = (az_ + 180) % 360 - 180
        # 20면 덩이(subdiv 0) — 낮은 다각형 결에 맞고 정점이 적다(80면이면 온 혼자 정점 +1만 1천).
        r_ = 0.022 + rng.uniform(-0.002, 0.004)
        cen = surface_point(az_, el_, float(on_top_thick(np.array(az_), np.array(el_))) + 0.002 - r_ * 0.3)
        bv, bt = ico_blob(cen, [r_, r_ * 0.85, r_], subdiv=0, jitter=0.10, seed=int(rng.integers(1e6)),
                          rot_y=float(rng.uniform(0, 6.28)))
        pieces.append((bv, godot_winding(bv, bt, cen)))
ov, ot = merge(pieces)
# 위를 1.80 m 아래로 부드럽게 누른다(키 180 cm 규칙).
high = ov[:, 1] > ON_TOP - 0.025
ov[high, 1] = (ON_TOP - 0.025) + (ov[high, 1] - (ON_TOP - 0.025)) * 0.5
ov[:, 1] = np.minimum(ov[:, 1], ON_TOP)
styles['on'] = pack([(fade[0], fade[1], 'fade'), (ov, ot, 'hair')])


# ---------- 5. 입체 눈썹(이마 앞, 눈알보다 앞) ----------
SKIN = ~hair & ~ear


def front_z(x, y, r=0.006):
    """(x, y) 근처 살 정점 중 가장 앞(가장 작은 z) — 이마 표면."""
    m = SKIN & (np.abs(P[:, 0] - x) < r) & (np.abs(P[:, 1] - y) < r) & (P[:, 2] < -0.1)
    return P[m][:, 2].min()


def brow(side, xs, ys, hs, depth, back_sink=0.004, tilt=0.35):
    """xs·ys·hs = 안쪽→바깥 제어점(가운데 x, 가운데 높이, 세로 두께). depth = 이마에서 앞으로 나온 깊이.
    단면 = 위 뒤 · 위 앞 · 아래 앞 · 아래 뒤(앞면이 아래로 조금 기울어 빛을 받는 윗면이 생긴다)."""
    V_ = []
    for x, y, h, dp in zip(xs, ys, hs, depth):
        x = x * side
        zf = front_z(x, y)
        V_ += [[x, y + h / 2, zf + back_sink], [x, y + h / 2 - h * tilt * 0.3, zf - dp],
               [x, y - h / 2, zf - dp * 0.8], [x, y - h / 2, zf + back_sink]]
    n = len(xs)
    T_ = []
    for i in range(n - 1):
        for a_, b_ in [(0, 1), (1, 2), (2, 3)]:
            p0, p1, q0, q1 = 4 * i + a_, 4 * i + b_, 4 * (i + 1) + a_, 4 * (i + 1) + b_
            T_ += [[p0, p1, q1], [p0, q1, q0]]
    for c in (0, n - 1):                     # 끝 마개
        b = 4 * c
        T_ += [[b, b + 1, b + 2], [b, b + 2, b + 3]]
    V_ = np.array(V_)
    cen = np.array([V_[:, 0].mean(), V_[:, 1].mean(), V_[:, 2].max() + 0.02])
    return {'v': np.round(V_, 5).tolist(), 't': godot_winding(V_, T_, cen), 'c': 'brow', 'bone': 'head', 'shade': 0.0}


def brow_set(xs, ys, hs, depth):
    return [brow(s, xs, ys, hs, depth) for s in (1, -1)]


BROWS = {
    # 준: 굵고 곧게, 안쪽 끝이 낮다(진지한 눈매)
    'jun': brow_set([0.026, 0.042, 0.060, 0.078, 0.094, 0.106], [1.639, 1.642, 1.646, 1.649, 1.650, 1.648],
                    [0.012, 0.013, 0.012, 0.011, 0.009, 0.006], [0.009, 0.010, 0.010, 0.010, 0.009, 0.007]),
    # 솜: 가늘게 둥근 아치, 바깥으로 갈수록 가늘다
    'som': brow_set([0.030, 0.045, 0.062, 0.078, 0.092, 0.104], [1.643, 1.650, 1.656, 1.657, 1.653, 1.645],
                    [0.0065, 0.0070, 0.0065, 0.0055, 0.0045, 0.0030], [0.006, 0.007, 0.007, 0.007, 0.006, 0.005]),
    # 온: 짧고 두툼한 각진 눈썹
    'on': brow_set([0.030, 0.048, 0.066, 0.082, 0.096], [1.643, 1.647, 1.650, 1.650, 1.646],
                   [0.016, 0.017, 0.016, 0.014, 0.011], [0.011, 0.012, 0.012, 0.011, 0.009]),
}


# ---------- 6. 덧붙이는 조각(소맷단·밑단·깃·탭·속눈썹) ----------
TOP = np.array(d['Top_01']['surfaces'][0]['pos']); TOPN = np.array(d['Top_01']['surfaces'][0]['nor'])
BOT = np.array(d['Bottom_01']['surfaces'][0]['pos'])
SHO = np.vstack([np.array(s_['pos']) for s_ in d['Shoes_01']['surfaces']])


def frame(axis):
    a = axis / np.linalg.norm(axis)
    ref = np.array([0, 0, 1.0]) if abs(a[2]) < 0.9 else np.array([1.0, 0, 0])
    u = np.cross(a, ref); u /= np.linalg.norm(u)
    w = np.cross(a, u)
    return a, u, w


def ring_band(points, origin, axis, t0, t1, n=16, pad=0.005, flare=0.002):
    """points(옷 정점)의 축 둘레 단면을 따라 t0~t1 띠를 감싸는 낮은 폴리 고리."""
    a, u, w = frame(axis)
    rel = points - origin
    t = rel @ a
    sel = (t > t0 - 0.01) & (t < t1 + 0.01)
    q = rel[sel] - np.outer(t[sel], a)
    ang = np.arctan2(q @ w, q @ u)
    rad = np.linalg.norm(q, axis=1)
    bins = np.linspace(-np.pi, np.pi, n + 1)
    R = np.full(n, np.nan)
    for i in range(n):
        m = (ang >= bins[i]) & (ang < bins[i + 1])
        if m.any():
            R[i] = rad[m].max()
    R[np.isnan(R)] = np.nanmean(R)
    th = (bins[:-1] + bins[1:]) / 2

    def ring(tt, rr):
        return [origin + a * tt + (u * np.cos(th[i]) + w * np.sin(th[i])) * rr[i] for i in range(n)]
    outer0 = ring(t0, R + pad)
    outer1 = ring(t1, R + pad + flare)
    inner1 = ring(t1, R - 0.002)
    inner0 = ring(t0, R - 0.002)
    V_ = np.array(outer0 + outer1 + inner1 + inner0)
    T_ = []
    for i in range(n):
        j = (i + 1) % n
        for ra, rb in [(0, 1), (1, 2), (3, 0)]:
            T_ += [[ra * n + i, rb * n + i, rb * n + j], [ra * n + i, rb * n + j, ra * n + j]]
    return V_, T_, origin + a * (t0 + t1) / 2, a


def godot_winding_axis(verts, tris, center, axis):
    """축 둘레 고리: 축에서 바깥을 보는 면이 앞면. 끝 마개는 중심에서 바깥으로."""
    out = []
    for a_, b_, c_ in tris:
        n_ = np.cross(verts[b_] - verts[a_], verts[c_] - verts[a_])
        m_ = (verts[a_] + verts[b_] + verts[c_]) / 3 - center
        radial = m_ - axis * (m_ @ axis)
        ref = radial if abs(np.dot(n_ / (np.linalg.norm(n_) + 1e-12), axis)) < 0.7 else m_
        out.append([int(a_), int(c_), int(b_)] if np.dot(n_, ref) > 0 else [int(a_), int(b_), int(c_)])
    return out


extras = {'jun': [], 'som': [], 'on': []}

# 준: 소매 끝 황토 접은 소맷단
for side, bone in [(1, 'upper_arm.R'), (-1, 'upper_arm.L')]:
    sh = np.array([0.175 * side, 1.208, 0.006]); el = np.array([0.367 * side, 0.964, 0.028])
    ax = el - sh; axn = ax / np.linalg.norm(ax)
    sleeve = TOP[(TOP[:, 0] * side > 0.17)]
    tmax = ((sleeve - sh) @ axn).max()
    V_, T_, cen, a_ = ring_band(sleeve, sh, ax, tmax - 0.032, tmax + 0.004, n=16, pad=0.006, flare=0.003)
    extras['jun'].append({'v': np.round(V_, 5).tolist(), 't': godot_winding_axis(V_, T_, cen, a_), 'c': 'accent', 'bone': bone, 'shade': 0.02})


def neck_ring(n=28):
    neck = TOP[TOP[:, 1] > 1.20]
    ang = np.arctan2(neck[:, 0], -(neck[:, 2] + 0.02))
    bins = np.linspace(-np.pi, np.pi, n + 1)
    pts = []
    for i in range(n):
        m = (ang >= bins[i]) & (ang < bins[i + 1])
        cand = neck[m]
        rr = np.hypot(cand[:, 0], cand[:, 2] + 0.02)
        inner = cand[rr < 0.10]
        cand = inner if len(inner) else cand
        pts.append(cand[np.argmax(cand[:, 1])])
    return np.array(pts), (bins[:-1] + bins[1:]) / 2


NR, NA = neck_ring()


def collar(open_deg, rise, outward, tilt_out, color, bone='chest'):
    """목둘레를 따라 세운(또는 눕힌) 깃. open_deg = 앞 가운데 벌어진 각(양쪽 합)."""
    keep = [i for i in range(len(NA)) if abs(np.degrees(NA[i])) > open_deg / 2]
    order = sorted(keep, key=lambda i: (NA[i] if NA[i] > 0 else NA[i] + 2 * np.pi))
    V_ = []
    for i in order:
        base = NR[i]
        out = np.array([np.sin(NA[i]), 0, -np.cos(NA[i])])
        V_ += [base + out * outward - np.array([0, 0.004, 0]), base + out * (outward + tilt_out) + np.array([0, rise, 0])]
    T_ = []
    for k in range(len(order) - 1):
        a0, a1, c0_, c1_ = 2 * k, 2 * k + 1, 2 * k + 2, 2 * k + 3
        T_ += [[a0, a1, c1_], [a0, c1_, c0_]]
    V_ = np.array(V_)
    cen = np.array([0.0, NR[:, 1].mean() - 0.05, -0.02])
    return {'v': np.round(V_, 5).tolist(), 't': godot_winding(V_, T_, cen), 'c': color, 'bone': bone, 'shade': 0.02}


extras['jun'].append(collar(open_deg=64, rise=0.009, outward=0.006, tilt_out=0.016, color='shirt'))
extras['on'].append(collar(open_deg=34, rise=0.030, outward=0.004, tilt_out=-0.004, color='shirt'))

# 솜: 바짓단 연청록 접단
for side, bone in [(1, 'shin.R'), (-1, 'shin.L')]:
    kn = np.array([0.123 * side, 0.385, 0.015]); an = np.array([0.150 * side, 0.086, 0.024])
    ax = an - kn; axn = ax / np.linalg.norm(ax)
    leg = BOT[(BOT[:, 0] * side > 0.02) & (BOT[:, 1] < 0.40)]
    tmax = ((leg - kn) @ axn).max()
    V_, T_, cen, a_ = ring_band(leg, kn, ax, tmax - 0.040, tmax + 0.002, n=16, pad=0.006, flare=0.001)
    extras['som'].append({'v': np.round(V_, 5).tolist(), 't': godot_winding_axis(V_, T_, cen, a_), 'c': 'turnup', 'bone': bone, 'shade': 0.02})

# 솜: 속눈썹(눈 바깥 위쪽 작은 쐐기 3개)
EYES = {1: np.array([0.0735, 1.5955, -0.2027]), -1: np.array([-0.0665, 1.5972, -0.2065])}
for side in (1, -1):
    c_ = EYES[side]
    V_ = []; T_ = []
    for ang, ln in [(62, 0.014), (40, 0.019), (18, 0.016)]:
        a_ = np.radians(ang)
        dirv = np.array([side * np.cos(a_), np.sin(a_), -0.35]); dirv /= np.linalg.norm(dirv)
        root = c_ + np.array([side * np.cos(a_) * 0.9, np.sin(a_) * 0.9, -0.45]) * 0.026
        tip = root + dirv * ln
        perp = np.cross(dirv, np.array([0, 0, -1.0])); perp /= np.linalg.norm(perp)
        b = len(V_)
        V_ += [root + perp * 0.0035, root - perp * 0.0035, tip, root + np.array([0, 0, 0.004])]
        T_ += [[b, b + 1, b + 2], [b + 3, b, b + 2], [b + 3, b + 2, b + 1], [b + 3, b + 1, b]]
    V_ = np.array(V_)
    extras['som'].append({'v': np.round(V_, 5).tolist(), 't': godot_winding(V_, T_, c_ + np.array([0, 0, 0.01])), 'c': 'brow', 'bone': 'head', 'shade': 0.0})

# 온: 허리 양옆 청회색 캡슐 탭
for side in (1, -1):
    sel = (np.abs(TOP[:, 1] - 0.815) < 0.012) & (TOP[:, 2] < 0) & (np.abs(TOP[:, 0] - 0.145 * side) < 0.012)
    k_ = np.argmin(TOP[sel][:, 2])
    p0 = TOP[sel][k_]; nrm = TOPN[sel][k_]
    cen = p0 + nrm * 0.006
    yaw = np.arctan2(-nrm[0], -nrm[2])
    V_, T_ = ico_blob(cen, [0.042, 0.015, 0.012], subdiv=1, jitter=0.03, seed=40 + side)
    R = np.array([[np.cos(yaw), 0, np.sin(yaw)], [0, 1, 0], [-np.sin(yaw), 0, np.cos(yaw)]])
    V_ = (V_ - cen) @ R.T + cen
    extras['on'].append({'v': np.round(V_, 5).tolist(), 't': godot_winding(V_, T_.tolist(), cen), 'c': 'tab', 'bone': 'hips', 'shade': 0.02})

# 온: 신발 뒤꿈치 벽돌색 고리 탭
for side, bone in [(1, 'foot.R'), (-1, 'foot.L')]:
    sh_ = SHO[(SHO[:, 0] * side > 0)]
    xc = sh_[:, 0].mean()
    back = sh_[(np.abs(sh_[:, 0] - xc) < 0.02) & (sh_[:, 1] > 0.08)]
    z = back[:, 2].max(); y = back[:, 1].max()
    cen = np.array([xc, y + 0.004, z - 0.006])
    V_, T_ = ico_blob(cen, [0.011, 0.022, 0.008], subdiv=1, jitter=0.02, seed=50 + side)
    extras['on'].append({'v': np.round(V_, 5).tolist(), 't': godot_winding(V_, T_.tolist(), cen), 'c': 'pull', 'bone': bone, 'shade': 0.0})


# 입체 눈썹(5번에서 만든 것)
for id_, parts_ in BROWS.items():
    extras[id_] += parts_

out = {
    'extras': extras,
    'head_surface': 2,
    'moved_idx': moved.tolist(),
    'moved_pos': np.round(NP[moved], 6).tolist(),
    'hair_count': int(hair.sum()),
    'styles': styles,
}
json.dump(out, open(f'{HERE}/geo.json', 'w'))
print('hair verts', int(hair.sum()), 'moved', len(moved))
for k, s in styles.items():
    print(k, [(len(p['v']), len(p['t'])) for p in s])
