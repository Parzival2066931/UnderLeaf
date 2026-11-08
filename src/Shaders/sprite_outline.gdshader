// Sprite Outline
// A pixel-exact outline for 2D sprites, drawn outside or inside the art, safe on atlases.
// Godot 4.7 · CC0 1.0 · godotlearning.com/shaders/sprite-outline
shader_type canvas_item;

// Outline thickness, counted in texels of the sprite's texture, not in screen pixels.
uniform int width : hint_range(1, 8) = 1;
// Outline colour. Lower its alpha for a see-through outline.
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Off: the outline grows outward into transparent pixels.
// On: it recolours the sprite's own edge pixels instead.
uniform bool inside = false;
// Which neighbours count as touching:
// Diamond skips corners, Circle rounds them, Square keeps them.
uniform int pattern : hint_enum("Diamond", "Circle", "Square") = 0;

// A texel whose alpha is at least this much counts as part of the sprite.
const float ALPHA_CUT = 0.5;

// The node's modulate and self_modulate, without the texture.
// Used to tint and fade the outline along with the sprite.
varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

// True when uv lies inside this sprite's own rectangle of the texture (lo..hi).
// Samples outside it count as empty, so a neighbouring atlas frame is never read.
bool in_region(vec2 uv, vec2 lo, vec2 hi) {
	return all(greaterThanEqual(uv, lo)) && all(lessThanEqual(uv, hi));
}

// True when the offset (x, y) is inside the neighbourhood picked by `pattern`.
bool in_pattern(int x, int y, int w) {
	if (pattern == 0) {
		return abs(x) + abs(y) <= w;
	}
	if (pattern == 1) {
		return x * x + y * y <= w * w + w;
	}
	return true;
}

void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE;
	// The part of the texture this sprite draws, in UV: a Sprite2D region, an
	// AtlasTexture frame or the whole texture. flip_h and flip_v make the size
	// negative while the rectangle stays where it is, hence abs().
	vec2 lo = max(REGION_RECT.xy, vec2(0.0));
	vec2 hi = min(REGION_RECT.xy + abs(REGION_RECT.zw), vec2(1.0));
	// Snap to the centre of the current texel, so every sample lands on a texel centre
	// however much the sprite is scaled.
	vec2 centre = (floor(UV / texel) + 0.5) * texel;
	// textureLod at level 0 on purpose: texture() picks a mip level from screen-space
	// derivatives, and those are not reliable inside a loop that can stop early.
	bool own = in_region(centre, lo, hi) && textureLod(TEXTURE, centre, 0.0).a >= ALPHA_CUT;

	// Outside mode looks for a solid neighbour around an empty texel.
	// Inside mode looks for an empty neighbour around a solid texel.
	if (own == inside) {
		bool edge = false;
		for (int y = -width; y <= width && !edge; y++) {
			for (int x = -width; x <= width; x++) {
				if ((x == 0 && y == 0) || !in_pattern(x, y, width)) {
					continue;
				}
				vec2 sample_uv = centre + vec2(float(x), float(y)) * texel;
				bool solid = in_region(sample_uv, lo, hi)
						&& textureLod(TEXTURE, sample_uv, 0.0).a >= ALPHA_CUT;
				if (solid != own) {
					edge = true;
					break;
				}
			}
		}
		if (edge) {
			if (inside) {
				// COLOR.a already holds the texel alpha times modulate.a, so only
				// the colour's own alpha decides the blend. Fading stays a fade.
				COLOR.rgb = mix(COLOR.rgb, color.rgb * modulate.rgb, color.a);
			} else {
				COLOR = color * modulate;
			}
		}
	}
}
