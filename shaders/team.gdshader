shader_type canvas_item;
// Swaps the two key reds in the sprites for the owning player's colour.
uniform vec4 team : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float flash = 0.0;
uniform vec3 tint = vec3(1.0);   // e.g. a powered-down construct goes cold grey
// a faint colour washed over the picture at its own brightness (a Sire's eggs: scripts/brood_new.gd egg_wash):
// rgb the colour, a how much (0: none)
uniform vec4 wash = vec4(1.0, 1.0, 1.0, 0.0);

// Horse coats (tools/import_horse_coats.py): a mask beside each horse strip says which pixels
// are the horse (R), where a spotted coat has a patch (G) and the pixel's tone (B); the
// horse's tone is mapped onto the coat's row of coat_ramps. coat < 0: as painted.
uniform int coat = -1;           // 0 dark, 1 bay, 2 grey, 3 white, 4 spotted (white + patches)
uniform sampler2D horse_mask : filter_nearest, repeat_disable, hint_default_black;
uniform sampler2D coat_ramps : filter_linear, repeat_disable;
// A Crown soldier's small trim (scripts/vet_look.gd, tools/import_vet_trim.py: hat lace, hat band, helmet comb and
// brim): a mask beside each strip marks its pixels (R) and their tone (G, dark 0 .. light 1); vet_style 1 draws them
// black (veterancy itself is the chevron over the unit since 0.36.x, scripts/vet_chevrons.gd). 0: as painted.
uniform int vet_style = 0;
uniform sampler2D vet_mask : filter_nearest, repeat_disable, hint_default_black;
// a Powder Wagon whose horse was released (RELEASE HORSE): its painted horse isn't drawn
uniform bool hide_horse = false;
// THE VENOM LINE (the Spitter, the Venom Challenger, the Venom Sire; tools/import_venom_colours.py, docs/venom_belly.md):
// the spikes and the frill in the team colour as the rest of the Brood (the key reds), the scales olive as painted, and
// the BELLY and a STRIPE along the flank in the team colour. A mask beside each strip: R = a belly or stripe pixel and G
// its tone (dark 0 .. light 1).
uniform bool venom_swap = false;
uniform sampler2D venom_mask : filter_nearest, repeat_disable, hint_default_black;

vec3 coat_ramp(int row, float t) {
	return texture(coat_ramps, vec2(t * (63.0 / 64.0) + 0.5 / 64.0, (float(row) + 0.5) / 5.0)).rgb;
}

// (keep the colours in step with tools/import_vet_trim.py)
vec3 vet_trim(float t) {
	return mix(vec3(0.05, 0.05, 0.06), vec3(0.22, 0.22, 0.24), t);                   // black
}

// (keep the ramp in step with tools/import_venom_colours.py)
vec3 team_ramp(vec3 t, float x) {
	vec3 c = mix(t * 0.24, t * 0.85, smoothstep(0.0, 0.7, x));
	return mix(c, mix(t, vec3(1.0), 0.35), smoothstep(0.7, 1.0, x));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 o = c.rgb;
	if (distance(c.rgb, vec3(1.0, 0.0, 0.0)) < 0.08) o = team.rgb;
	else if (distance(c.rgb, vec3(150.0 / 255.0, 0.0, 0.0)) < 0.08) o = team.rgb * 0.6;
	else if (coat >= 0) {
		vec4 m = texture(horse_mask, UV);
		if (m.r > 0.5) {
			vec3 col = coat == 4 ? mix(coat_ramp(3, m.b), coat_ramp(4, m.b), m.g) : coat_ramp(coat, m.b);
			// the outline darks stay as painted
			float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
			o = mix(c.rgb, col, smoothstep(0.035, 0.10, l));
		}
	}
	bool venom_scale = false;
	if (venom_swap) {
		vec4 nm = texture(venom_mask, UV);
		if (nm.r > 0.5) {
			vec3 sc = team_ramp(team.rgb, nm.g);
			// the outline darks stay as painted
			float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
			o = mix(c.rgb, sc, smoothstep(0.035, 0.10, l));
			venom_scale = true;
		}
	}
	if (vet_style == 1 && !venom_scale) {
		vec4 vm = texture(vet_mask, UV);
		if (vm.r > 0.5) o = vet_trim(vm.g);
	}
	if (wash.a > 0.0) {
		vec3 lw = vec3(0.299, 0.587, 0.114);
		vec3 wc = min(wash.rgb * (dot(o, lw) / max(dot(wash.rgb, lw), 0.05)), vec3(1.0));
		o = mix(o, mix(wc, wash.rgb, 0.3), wash.a);
	}
	o = mix(o, vec3(1.0), flash);
	float a = c.a;
	if (hide_horse && texture(horse_mask, UV).r > 0.5) a = 0.0;
	COLOR = vec4(o * tint, a * COLOR.a);
}
