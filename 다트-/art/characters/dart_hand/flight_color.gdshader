shader_type canvas_item;
uniform vec4 seat_color : source_color = vec4(1.0);
uniform bool replace_flight = false;

void fragment() {
	vec4 pix = texture(TEXTURE, UV);
	// 깃은 오른쪽의 산호색 영역이다. 피부와 자루는 원화의 색을 쓴다.
	if (replace_flight && UV.x > 0.58 && pix.g < pix.b * 1.26 && pix.r > pix.g * 1.35) {
		pix.rgb = seat_color.rgb * (pix.r / 0.91);
	}
	COLOR = pix;
}
