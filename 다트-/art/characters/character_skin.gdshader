// [캐릭터 3안] 피부·머리 색 바꾸기 — 앞면만 그리는 면(원본 재질이 cull_back). 내용은 character_skin.gdshaderinc.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://art/characters/character_skin.gdshaderinc"
