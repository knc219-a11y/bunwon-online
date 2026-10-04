shader_type canvas_item;
// 맞으면 번쩍 (2026-10-03 타격감): flash 1 이면 그림 모양 그대로 flash_color 로 칠한다.
// 몸 색 (modulate) 은 먼저 곱해지므로 어떤 색 몬스터든 같은 색으로 번쩍인다. 투명한 곳은 그대로.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, flash);
}
