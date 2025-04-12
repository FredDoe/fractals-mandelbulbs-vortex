#define EPSILON 0.001
#define PI 3.141592
#define MAX_DIST 256.0
#define MAX_STEPS 256
#define it 10

vec3 makeRay(vec2 origin)
{
    vec2 res;
    res.x = origin.x - iResolution.x * 0.5;
    res.y = origin.y - iResolution.y * 0.5;
    
    return normalize(vec3(res / iResolution.yy, 1));
}

mat2 rot(float ang)
{
    float s = sin(ang);
    float c = cos(ang);
    return mat2(c, -s, s, c);
}

vec3 rotVec(vec3 p, vec3 r)
{
    p.yz *= rot(r.x);
    p.xz *= rot(r.y);
    p.xy *= rot(r.z);
    return p;
}

float mandelBulb(vec3 p, vec3 fp, float power, vec3 ang)
{
    p -= fp;
    p = rotVec(p, ang);
    
	vec3 z = p;
	float r, theta, phi;
	float dr = 1.0;
	
	for(int i = 0; i < it; ++i)
    {
		r = length(z);
        
		if(r > 2.0)
            continue;
        
		theta = atan(z.y / z.x);
        phi = asin(z.z / r) + iTime;
		
		dr = pow(r, power - 1.0) * dr * power + 1.0;
		r = pow(r, power);
        
		theta = theta * power;
		phi = phi * power;
		
		z = r * vec3(cos(theta) * cos(phi),
                     sin(theta) * cos(phi), 
                     sin(phi)) + p;
	}
    
	return 0.5 * log(r) * r / dr;
}

float getDist(vec3 origin)
{
    vec3 fp = vec3(0);
    vec3 fr = vec3(0, PI + PI / 4.0, 0);
    float power = 8.0;
    
    return mandelBulb(origin, fp, power, fr);
}

vec2 rayMarch(vec3 origin, vec3 direct)
{
    float res = 0.0;
    
    for (int i = 0; i < MAX_STEPS; i++)
    {
        vec3 tmp = origin + direct * res;
        float d = getDist(tmp);
        res += d;
        
        if (res >= MAX_DIST || d < EPSILON)
        	return vec2(res, float(i));
    }

    return vec2(res, float(MAX_STEPS));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec3 origin = vec3(0, 0, -3);
    vec3 dir = makeRay(fragCoord);
    
    vec2 res = rayMarch(origin, dir);
    float d = res.x;
    vec3 col;
    
    vec3 startCol = vec3(cos(iTime) * 0.25 + 0.75, 0, 0);
    vec3 finCol = vec3(0, 0, sin(iTime) * 0.25 + 0.75);
    float delta = 0.5;
    
    if (d < MAX_DIST)
    {
    	vec3 p = origin + d * dir;
        delta = length(p) / 2.0;
    }
    
    col = mix(startCol, finCol, delta) * res.y / float(MAX_STEPS) * 5.0;
    fragColor = vec4(col, 1);
}