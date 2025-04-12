const int NUM_STEPS = 40;
const float CELL_SIZE = 0.3;
const float RADIUS = 0.1;
const float EPSILON = 1e-3;

const vec3 RED = vec3(1.0, 0.0, 0.0);
const vec3 ORANGE = vec3(1.0, 0.647, 0.0);
const vec3 YELLOW = vec3(1.0, 1.0, 0.0);
const vec3 GREEN = vec3(0.0, 1.0, 0.0);
const vec3 INDIGO = vec3(0.0, 0.5, 1.0);
const vec3 BLUE = vec3(0.0, 0.0, 1.0);
const vec3 PURPLE = vec3(0.45, 0.0, 1.0);


// reference: https://www.shadertoy.com/view/Ms2SD1
float hash( vec2 p ) {
	float h = dot(p,vec2(127.1,311.7));	
    return fract(sin(h)*43758.5453123);
}

float noise( in vec2 p ) {
    vec2 i = floor( p );
    vec2 f = fract( p );	
	vec2 u = f*f*(3.0-2.0*f);
    return -1.0+2.0*mix( mix( hash( i + vec2(0.0,0.0) ), 
                     hash( i + vec2(1.0,0.0) ), u.x),
                mix( hash( i + vec2(0.0,1.0) ), 
                     hash( i + vec2(1.0,1.0) ),  u.x), u.y);
}

// polynomial smooth min (k = 0.1) from iq;
float smin( float a, float b, float k )
{
    float h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0 );
    return mix( b, a, h ) - k*h*(1.0-h);
}



float sdSphere( vec3 p, float s )
{
  return length(p)-s;
}

float sdTorus( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

float opRepSphere( vec3 p, vec3 c )
{
    vec3 q = mod(p,c)-0.5*c;
    return sdSphere( q, RADIUS );
}

float opRepTorus( vec3 p, vec3 c, vec2 t )
{
    vec3 q = mod(p,c)-0.5*c;
    return sdTorus( q, t );
}


float hash3d( vec3 p ) {
    float h = dot(p,vec3(1.127,3.117, 2.038));	
    return fract(sin(h)*71451.5453123);
}

mat2 rot( float angle ) {
    float c = cos(angle);
    float s = sin(angle);
    return mat2(c, -s, s, c);
}

float noise3d( in vec3 p ) {
    vec3 idx = vec3(fract(sin(dot(p / 0.3, vec3(2.5,3.46,1.29))) * 12394.426),
                   fract(sin(dot(p / 0.17, vec3(3.987,2.567,3.76))) * 52422.82465),
                   fract(sin(dot(p / 0.44, vec3(6.32,3.87,5.24))) * 34256.267));
    //p.z *= p.z;
    //p.y *= p.y;
    //p.z = mix(p.y, p.z, idx.x * (1.0 - idx.y));
    p.xz = mod(p.xz - 0.5 * CELL_SIZE, vec2(CELL_SIZE));
    p.xz = rot(fract(sin(dot(idx.xz, vec2(3.124,1.75)))) * 312.2) * p.xz;
    float s = hash3d(1e4 * p + idx);
    return s;
}

vec3 colorLookup( in vec3 p ) {
    float freq = 1e-7;
    float f = noise3d(p * freq);
    if (f < 1.0 / 7.0) return RED;
    if (f < 2.0 / 7.0) return ORANGE;
    if (f < 3.0 / 7.0) return YELLOW;
    if (f < 4.0 / 7.0) return GREEN;
    if (f < 5.0 / 7.0) return INDIGO;
    if (f < 6.0 / 7.0) return BLUE;
    return PURPLE;
}

float map (in vec3 p) {
    float bailout = 2.0;
    float power = 3.0 * sin(iTime / 5.0) + 6.0;
    vec3 z = p;
    float dr = 1.0;
    float r = 0.0;
    for (int i = 0; i < 200; i++) {
        r = length(z);
        if (r>bailout) break;

        // convert to polar coordinates
        float theta = acos(z.z/r);
        float phi = atan(z.y,z.x);
        dr =  pow( r, power-1.0)*power*dr + 1.0;

        // scale and rotate the point
        float zr = pow( r,power);
        theta = theta*power;
        phi = phi*power;

        // convert back to cartesian coordinates
        z = zr*vec3(sin(theta)*cos(phi), sin(phi)*sin(theta), cos(theta));
        z += p;
    }
    return 0.5*log(r)*r/dr;
}

vec3 calcNormal( in vec3 pos )
{
    vec2 e = vec2(1.0,-1.0)*0.5773*0.0005;
    return normalize( e.xyy*map( pos + e.xyy ) + 
					  e.yyx*map( pos + e.yyx ) + 
					  e.yxy*map( pos + e.yxy ) + 
					  e.xxx*map( pos + e.xxx ) );
    /*
	vec3 eps = vec3( 0.0005, 0.0, 0.0 );
	vec3 nor = vec3(
	    map(pos+eps.xyy).x - map(pos-eps.xyy).x,
	    map(pos+eps.yxy).x - map(pos-eps.yxy).x,
	    map(pos+eps.yyx).x - map(pos-eps.yyx).x );
	return normalize(nor);
	*/
}


bool interSect( vec3 ro, vec3 rd, out vec3 p ) {
    float t = 0.0;
    p = ro;
    for (int i = 0; i < NUM_STEPS; i++) {
        p = ro + t * rd;
        float d = map(p);
        if (abs(d) < EPSILON) {
            return true;
        }
        t += d;
    }
    return false;
}

mat3 cam2world(vec3 ro, vec3 target, vec3 up) {
    vec3 forward = normalize(target - ro);
    vec3 right = cross(up, forward);
    return mat3(right, up, forward);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec3 light_dir = normalize(vec3(0.3, 0.4, -0.5));
	vec2 uv = fragCoord.xy / iResolution.xy;
    uv = uv * 2.0 - 1.0;
    uv.x *= iResolution.x / iResolution.y;
    
    vec3 ro = vec3(rot(iTime / 5.0) * vec2(sin(iTime / 2.0) + 2.5, 0.0), 0.0);
    //vec3 ro = vec3(rot(iTime / 5.0) * vec2(3.0, 0.0), 0.0);
    vec3 target = vec3(0.0);
    vec3 up = vec3(0.0, 0.0, 1.0);
    vec3 rd = cam2world(ro, target, up) * normalize(vec3(uv, 2.1));
    float t = 0.0;
    vec3 p, norm;
    if (interSect(ro, rd, p)) {
    //if (rayTracing(ro, rd, t)) {
    //if (abs(sdf(ro + t * rd)) < EPSILON) {
        norm = calcNormal(p);
        vec3 baseColor = colorLookup(p);
        float light_pow = 2.0;
        float brdf = 0.4;
        vec3 diff = vec3(dot(light_dir, norm) * brdf * light_pow);
        fragColor = vec4(mix(baseColor, diff, 0.99), 1.0);
        //fragColor = vec4(1.0, 0.0, 0.0, 1.0);
    } else {
        fragColor = vec4(0,0,0,1.0);
    }
    fragColor.xyz = pow(fragColor.xyz, vec3(1.0/2.2));
	
}