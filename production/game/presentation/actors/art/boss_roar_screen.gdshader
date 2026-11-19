shader_type canvas_item;
render_mode unshaded;
uniform sampler2D world_image : hint_screen_texture, filter_nearest, repeat_disable;
uniform float progress = 0.0;
uniform float release_progress = .30;
uniform float strength = 1.0;
uniform vec2 mouth = vec2(.72,.53);

float hash(float x) { return fract(sin(x*127.1+17.7)*43758.5453); }

void fragment() {
	vec2 viewport=1.0/SCREEN_PIXEL_SIZE;
	vec2 uv=(floor(SCREEN_UV*viewport/2.0)+.5)*2.0/viewport;
	float aspect=viewport.x/viewport.y;
	vec2 q=(uv-mouth)*vec2(aspect,1.0);
	float distance=length(q);
	vec2 radial=q/max(.001,distance);
	float angle=atan(q.y,q.x);
	float roar=smoothstep(release_progress-.02,release_progress+.04,progress)*(1.0-smoothstep(.82,1.0,progress));
	float burst=exp(-pow((progress-release_progress-.035)*27.0,2.0));
	float voice_pulse=.78+.22*sin(max(0.0,progress-release_progress)*93.0);
	float breath=sin(clamp(progress/release_progress,0.0,1.0)*3.14159265)*(1.0-step(release_progress,progress));
	// Three irregular pressure fronts cross the whole screen, not just the feet.
	float wave=0.0;
	float crest=0.0;
	for(int i=0;i<3;i++) {
		float age=progress-release_progress-float(i)*.105;
		float radius=age*5.6;
		float wobble=sin(angle*11.0+float(i)*2.0)*.009;
		float width=.012+max(0.0,age)*.020;
		float ring=exp(-pow((distance-radius+wobble)/width,2.0))*step(0.0,age);
		wave+=ring*(1.0-float(i)*.20);
		crest+=ring*(.22+max(0.0,cos(angle*17.0+float(i)))*.5);
	}
	// World-only shudder/distortion. HUD is drawn afterwards and stays legible.
	vec2 shudder=vec2(sin(progress*237.0),cos(progress*191.0))*(burst*4.0+roar*1.35);
	vec2 refraction=radial*vec2(1.0/aspect,1.0)*(wave*4.5+sin(distance*50.0-progress*93.0)*roar*.8);
	vec2 offset=floor((shudder+refraction)*strength+.5)*SCREEN_PIXEL_SIZE;
	vec3 scene=texture(world_image,clamp(SCREEN_UV+offset,vec2(0.0),vec2(1.0))).rgb;
	float edge=smoothstep(.22,.75,length((uv-vec2(.5))*vec2(1.25,1.0)));
	scene*=1.0-(edge*(roar*.36+breath*.14)+roar*.085)*strength;
	// Fast broken radial wind cuts, in differently sized sectors.
	float sector=floor((angle+3.14159265)*45.0);
	float thin=pow(max(0.0,cos(angle*90.0)),38.0);
	float run=fract(distance*1.65-progress*8.0+hash(sector));
	float streak=thin*smoothstep(.70,.79,run)*(1.0-smoothstep(.88,.96,run))*smoothstep(.08,.25,distance);
	float air=pow(max(0.0,sin(uv.y*137.0+sin(uv.x*9.0-progress*19.0))),32.0);
	vec3 wind=vec3(.65,.85,.79)*(crest*.32+streak*roar*.38+air*roar*.085);
	scene+=wind*strength;
	scene+=vec3(.91,.90,.70)*burst*.115*strength;
	COLOR=vec4(scene,1.0);
}
