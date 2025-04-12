#define distfar 6.0
#define iterations 4

vec3 c;

float calcfractal(vec3 coord) {
    vec3 orbit = coord;
    float dz = 1.0;
    
    for (int i=0; i<iterations; i++) {
        
        float r = length(orbit);
    	float o = acos(orbit.z/r);
    	float p = atan(orbit.y/orbit.x);
        
        dz = 8.0*r*r*r*r*r*r*r*dz;
        
        r = r*r*r*r*r*r*r*r;
        o = 8.0*o;
        p = 8.0*p;
        
        orbit = vec3( r*sin(o)*cos(p), r*sin(o)*sin(p), r*cos(o) ) + c;
        
        if (dot(orbit,orbit) > 4.0) break;
    }
    float z = length(orbit);
    return 0.5*z*log(z)/dz;
}

vec2 map(vec3 p) {
    return vec2(calcfractal(p.xzy),1.0);
}

vec3 trace(vec3 ro, vec3 rd) {
    float t = 0.0;
    for (float i = 0.0; i < 1000.0; i++) {
        if (t>distfar) break;
        vec2 h = map(ro + t*rd);
        if (h.x < 0.0001) return vec3(t, h.y, i);
        t += h.x;
    }
    return vec3(0.0);
}

vec3 calcnormal(vec3 p) {
    vec2 e = vec2(0.0001,0.0);
    vec3 n;
    n.x = map(p+e.xyy).x - map(p-e.xyy).x;
    n.y = map(p+e.yxy).x - map(p-e.yxy).x;
    n.z = map(p+e.yyx).x - map(p-e.yyx).x;
    return normalize(n);
}

float softshadow (vec3 ro, vec3 rd) {
    float res = 1.0;
    float t = 0.01;
    for (float i = 0.0; i < 1000.0; i++) {
        if (t>1.0) break;
        vec2 h = map(ro + t*rd);
        if (h.x < 0.0001) return 0.0;
        res = min(res, 4.0*h.x/t);
        t += h.x;
    }
    return res;
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 uv = fragCoord.xy / iResolution.xy;
    uv = (2.0)*uv-1.0;
    uv.x *= iResolution.x/iResolution.y;
    
    vec3 ro = vec3(0.0,0.0,-1.4);
    vec3 rd = normalize(vec3(uv,1.5));
    float the = 1.5*sin(iTime/30.0-1.0);
    mat2 rmat = mat2(cos(the),sin(the),-sin(the),cos(the));
    rd.yz *= rmat;
    ro.yz *= rmat;
    the = iTime/20.0;
    rmat = mat2(cos(the),sin(the),-sin(the),cos(the));
    rd.xz *= rmat;
    ro.xz*= rmat;
    c = vec3(0.6*sin(0.5*iTime),0.6*cos(0.784*iTime-1.203),0.6*sin(iTime*0.439485));
    
    vec3 t = trace(ro, rd);
    
    vec3 col = vec3(0.8);
    
    if (t.z > 0.0) {
        vec3 pos = ro + rd*t.x;
        vec3 nor = calcnormal(pos);
        vec3 lig = normalize(vec3(0.3,1.0,0.3));
        vec3 rdy = dot(nor, rd) * nor;
        vec3 rdx = rd - rdy;
        vec3 ref = rdx - rdy;
        
        float occ = clamp(0.0,1.0,1.0/(1.0+pow(t.z/30.0,3.0)));
        float sha = softshadow(pos, lig);
        float dif = max(0.0,dot(lig,nor));
        float sky = max(0.0,nor.y);
        float ind = max(0.0,dot(-lig,nor));
        float spec = pow( max(0.0,dot(ref,lig)) , 20.0);
        
        col  = dif*vec3(0.9,0.8,0.7)*vec3(sha);
        col += sky*vec3(0.16,0.20,0.24)*occ;
        col += ind*vec3(0.40,0.48,0.40)*occ;
        col += 0.1*occ;
        col += spec*sha*vec3(0.9,0.8,0.7);
        
        col = pow(col,vec3(0.45));
    }
    
	fragColor = vec4(col,1.0);
    
}