shader_type canvas_item;
uniform sampler2D structure_mask : filter_nearest;
uniform bool structure = false;
void fragment(){
 vec4 source = texture(TEXTURE,UV);
 float amount = texture(structure_mask,UV).a;
 COLOR = vec4(source.rgb,source.a*(structure?amount:1.0-amount));
}
void light(){
 float value = dot(COLOR.rgb,vec3(0.3,0.59,0.11));
 LIGHT = vec4(LIGHT_COLOR.rgb*vec3(value)*LIGHT_ENERGY,LIGHT_COLOR.a);
}
