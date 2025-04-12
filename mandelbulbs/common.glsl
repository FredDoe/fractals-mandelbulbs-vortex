// CONSTANTS ///////////////////////////////////////////
// Usual colors
const vec3 BLACK     = vec3(0);
const vec3 WHITE     = vec3(1);
const vec3 RED    	 = vec3(1,0,0);
const vec3 GREEN  	 = vec3(0,1,0);
const vec3 BLUE   	 = vec3(0,0,1);
const vec3 TEAL   	 = vec3(.21, .46, .53);
const vec3 VERMILION = vec3(.89, .26, .2); 

// Scene info
const int   NUM_SHAPES    = 1;
const int   NUM_LIGHTS    = 1;
const float FOG_DENSITY   = 0.175;
const float VIGNETTE_STR  = 0.25;
const vec3  SKY_COLOR     = vec3(0, .25, .5);
const vec3  FOG_COLOR     = WHITE;
const vec3  AMBIENT_LIGHT = TEAL*0.1;

// Ray marching variables
const int   MAX_ITERATIONS = 256;
const float MAX_DISTANCE   = 128.0;
const float EPSILON        = 0.0025;

// Shadows
const float SHADOW_BIAS    = EPSILON * 50.0;
const float SOFT_SHADOWS_C = 16.0;

// Ambient Occlusion
const int   AO_NUM_STEPS = 3;
const float AO_STEP_SIZE = 0.05;
const float AO_INTENSITY = 0.25;

// Shape types
const int FLOOR_PLANE = 0;
const int SPHERE      = 1;
const int BOX         = 2;
const int TORUS       = 3;
const int MANDELBULB  = 4;
const int NO_SHAPE    = 999;

// Blend operations
const int NO_OP = 0;
const int BLEND = 1;
const int CUT   = 2;
const int MASK  = 3;

// Light types
const int DIRECTIONAL = 0;
const int POINT       = 1;

// Reflections
const int   MAX_REFLECTION_STEPS = 1;
const float MAX_REFLECTION_DIST  = MAX_DISTANCE * .5;
const float REFLECTION_INTENSITY = .5;
////////////////////////////////////////////////////////

// SDFs ////////////////////////////////////////////////
// iquilezles.org/articles/distfunctions
float PlaneSDF(vec3 eye, vec3 p, vec4 n)
{ // NOTE: n must be normalized
    return dot(eye-p, n.xyz) + n.w;
}

float SphereSDF(vec3 eye, vec3 p, float r)
{ 
	return distance(p,eye) - r;
}

float BoxSDF(vec3 p, vec3 b )
{
    vec3 d = abs(p) - b;
    return length(max(d,0.0)) +
        	min(max(d.x,max(d.y,d.z)),0.0);
}

float TorusSDF(vec3 p, vec2 radii)
{
	vec2 q = vec2(length(p.xz) - radii.x, p.y);
    return length(q) - radii.y;
}

float MandelbulbSDF(vec3 position,
                    float power, float limit,
                    inout vec4 orbitTraps)
{
    float rad,phi,theta; // radius, azimuth and inclination
    float dr   = 1.0;
    float rad2 = dot(position, position);
    vec3  c = position;
    
    orbitTraps = vec4(abs(position), rad2);
    
    for (int i=0; i<4; i++)
    {
    	// Convert to polar coordinates
        rad   = length(c);
        theta = acos(c.y / rad);
        phi   = atan(c.x, c.z);
        
        dr = power * pow(rad, power-1.) * dr + 1.;
        
        // Scale and rotate
    	rad    = pow(rad, power);
   		phi   *= power;
    	theta *= power;
        
        // Back to cartesian
        c.x  = sin(phi) * sin(theta);
    	c.y  = cos(theta);
    	c.z  = sin(theta) * cos(phi);
    	c   *= rad;
    	
        c += position;
        
        orbitTraps = min(orbitTraps, vec4(abs(c), rad2));
        
        rad2 = dot(c,c);
        if (rad2 > limit*limit) break;
    }
    
    orbitTraps = vec4(rad2, orbitTraps.xyw); // Magnitude^2 | In X | In Y | Previous Magnitude^2

    //color = vec4(rad, color.xyw);
    return 0.25*log(rad2) * sqrt(rad2) / dr;
}
////////////////////////////////////////////////////////

// DATA STRUCTS ////////////////////////////////////////
struct Ray
{
    vec3 o;
    vec3 d;
};
    
struct Camera
{
    float fPersp;
    vec3  pos, forward, up, right;
};

struct Light
{
    int   type;
    float range, intensity;
    vec3  pos, dir;
    vec3  color;
};
    
struct Shape
{
    int    type, blendType;
    float  glossy, blendStrength;
    vec2   radii; // SPHERE: X
    			  // TORUS: X=external, Y=internal
    			  // MANDELBULB: X=power, Y=limit
    vec3   pos, scale;
    vec4   color, normal;
    mat3   rot;
};
    
struct RayIntersection
{
	int   numIt;
    float dist;
    float shadow;
    vec3  pos;
    Ray   ray;
    Shape shape;
};
    
struct Scene
{
    vec4 ambientLight;
    Camera cam;
    Light[NUM_LIGHTS] lights;
    Shape[NUM_SHAPES] objects;
};
////////////////////////////////////////////////////////
    
// GLOBALS /////////////////////////////////////////////
Scene scene;
////////////////////////////////////////////////////////