vec2 NormalizeScreenCoords(vec2 screenCoord)
{
    vec2 result = 2.0 * (screenCoord/iResolution.xy - 0.5);
    result.x *= iResolution.x/iResolution.y;
    return result;
}

float CheckersGradBox(vec2 p)
{ // iquilezles.org/articles/checkerfiltering
    vec2 w = fwidth(p) + .001;
    vec2 i = 2.0 * (abs(fract((p-.5*w)*.5)-.5)-abs(fract((p+.5*w)*.5)-.5))/w;
    return .5 - .5*i.x*i.y;
}

mat3 ComputeRotationMatrix(const float x, const float y, const float z)
{ // NOTE: mat = (firstCOLUMN, secondCOLUMN, thirdCOLUMN);
    mat3 o = mat3(0);
    
   	o  = mat3( 1.0, 0.0	,  0.0,		
             0.0, cos(x), -sin(x),
             0.0, sin(x), cos(x)  );
    
	o *= mat3( cos(y), 0.0, sin(y),
               0.0	 , 1.0, 0.0,
               -sin(y), 0.0, cos(y) );
    
	o *= mat3( cos(z), -sin(z), 0.0,
               sin(z), cos(z) , 0.0,
               0.0	 , 0.0    , 1.0 );
    return o;
}
///////////////////////////////////////////////////////////////////////////////

// Configure the scene
void SceneInit(out Scene s)
{
    // Setup camera
    s.cam.pos 	  = vec3(0,0,-2.5);
    s.cam.forward = vec3(0,0,1);
    s.cam.right   = normalize(cross(vec3(0, 1, 0), s.cam.forward));
    s.cam.up      = normalize(cross(s.cam.forward, s.cam.right));
    s.cam.fPersp  = 2.0;

    // Main Light
    Light dirLight;
	dirLight.type      = DIRECTIONAL;//POINT;
    dirLight.pos       = vec3(2,3,-1);
    dirLight.dir       = normalize(-dirLight.pos);
    dirLight.color 	   = vec3(0.35,0.30,0.25);
    dirLight.range     = MAX_DISTANCE;
    dirLight.intensity = 3.;

    s.lights[0] = dirLight;
    
    // Mandelbulb
    Shape mb;
    mb.blendType = NO_OP;
    mb.type      = MANDELBULB;
    mb.radii     = vec2(8.+ 2.*-cos(iTime*.1), 2);
    mb.pos       = vec3(0);
    mb.scale     = vec3(1);
    mb.rot  	 = ComputeRotationMatrix(cos(iTime*.25), sin(iTime*.25), 0.);
    mb.color     = vec4(VERMILION, 1);
    mb.normal    = vec4(0);
    mb.glossy    = 0.;
    
    s.objects[0] = mb;

    return;
}

void Blend(inout Shape current, inout float currentD,
           Shape candidate, float candidateD)
{ // Based on Iñigo Quilez's smooth min algorithm:
  // iquilezles.org/articles/smin
    
    float b = (candidate.blendStrength > 0.) ? candidate.blendStrength : EPSILON;
    float h = clamp(.5+.5*(candidateD-currentD)/b, 0., 1.);
    
    currentD       = mix(candidateD, currentD, h) -
                         candidate.blendStrength * h * (1.- h);
    current.color  = mix(candidate.color, current.color, h);
    current.normal = mix(candidate.normal, current.normal, h);
    
    // TODO: Find a better way to interpolate the texture / patterns
    current.type   = (h>=.5) ? current.type   : candidate.type;
	// TODO: Find a better way to interpolate glossiness
    current.glossy = (h>=.5) ? current.glossy : candidate.glossy;
}

float GetShapeDst(Shape s, vec3 eye, out vec4 aux)
{
    float o = MAX_DISTANCE + 1.;
    vec3 p = s.rot * (s.pos-eye);
    
    switch(s.type)
    {
        case FLOOR_PLANE:
        	o = PlaneSDF(eye, s.pos, s.normal);
        	break;
        case SPHERE:
           	o = SphereSDF(eye, s.pos, s.radii.x);
        	break;
        case BOX:
           	o = BoxSDF(p, s.scale);
        	break;
        case TORUS:
        	o = TorusSDF(p, s.radii);
        	break;
        case MANDELBULB:
        	o = MandelbulbSDF(p, s.radii.x, s.radii.y, aux);
        	break;
        default:
        	break;
    }
    
    return o;
}

RayIntersection GetNearestShape(vec3 origin)
{
    RayIntersection o;
    o.dist = MAX_DISTANCE;
    
    float shapeD;
    Shape s;
    
    for (int i=0; i<NUM_SHAPES; i++)
    {
        s = scene.objects[i];
		
        
        if (s.type == MANDELBULB)
        {
            shapeD = GetShapeDst(s, origin, s.color);
        }
        else
        {
            vec4 trash = vec4(0);
            shapeD = GetShapeDst(s, origin, trash);
        }
        
        switch (s.blendType)
        {
            case NO_OP:
                if (shapeD<o.dist)
        		{
            		o.shape = s;
            		o.dist  = shapeD;
        		}
            	break;
            
  			case BLEND:
            	Blend(o.shape, o.dist, s, shapeD);
            	break;
            
            case CUT: // TODO
            	break;
            
            case MASK: // TODO
            	break;
			
            default:
            	break;
        }
    }
    
    return o;
}

vec3 ComputeNormals(vec3 p)
{
    vec3 o;
    
    vec3 epsilonX = vec3(EPSILON, 0, 0);
    vec3 epsilonY = vec3(0, EPSILON, 0);
    vec3 epsilonZ = vec3(0, 0, EPSILON);
    
    // To estimate the normal in an axis, from a surface point, we move slightly
    // in that axis and get the changing in the distance to the surface itself.
    // If the change is 0 or really small it means the surface doesn't change in that
    // direction, so its normal in that point won't have that axis component.
    float reference = GetNearestShape(p).dist;
    o.x = GetNearestShape(p+epsilonX).dist - reference;
    o.y = GetNearestShape(p+epsilonY).dist - reference;
    o.z = GetNearestShape(p+epsilonZ).dist - reference;
    
    return normalize(o);
}

RayIntersection CastRay(const Ray r, const float max_dst)
{
    RayIntersection o;
    o.ray         = r;
 	o.dist        = MAX_DISTANCE;
    o.shadow      = MAX_DISTANCE;
    o.shape.type  = NO_SHAPE;
    
    int i = 0;
    float travelDist = EPSILON * .5;
    RayIntersection tmpRI;
    
    while (travelDist<max_dst && i<MAX_ITERATIONS)
    {
        i++;

		tmpRI = GetNearestShape(r.o + r.d*travelDist);
        
        travelDist += tmpRI.dist;
        
        // Soft shadows
        o.shadow = min(o.shadow, SOFT_SHADOWS_C*tmpRI.dist/travelDist);
        
        if (tmpRI.dist < EPSILON)
        { // We collided
            o.pos      = r.o + r.d*travelDist;
            o.shape    = tmpRI.shape;
            o.dist     = travelDist;

            if (o.shape.normal == vec4(0))
            { // Avoid computing the normals of shapes that already have them
              // (such as planes)
            	o.shape.normal = vec4(ComputeNormals(o.pos), 1);
            }
            break;
        }
    }
    
    if (o.shape.type == FLOOR_PLANE)
    {
    	o.shape.color = vec4(vec3(CheckersGradBox(o.pos.xz*.5)*.5 + .25), 1);
        o.shape.glossy *= o.shape.color.r;
    }

    o.numIt = i;
    return o;
}

Ray GetCameraRay(Camera cam, const vec2 uv)
{
    Ray o;
    
    o.o = cam.pos;
  	o.d = normalize(uv.x * cam.right +
                    uv.y * cam.up +
                    cam.forward * cam.fPersp);
    return o;
}

void ApplyFog(inout vec3 c, const float d)
{
    float m = exp(-d*d*.001);
    c = mix(FOG_COLOR, c, m);
}

void SmoothCubeMapHorizon(inout vec3 c, const vec3 cm, float d)
{
    float m = exp(-d*d*.001);
    c = mix(cm, c, m);
}

float ComputeShadow(const vec3 p, const vec3 n, const vec3 L, const float d2l)
{
    float shadow = 1.0;
    
    Ray r;
    r.o = p + n*SHADOW_BIAS; // Without this, the ray doesn't leave the surface
    r.d = L;
    
    RayIntersection ri = CastRay(r, d2l);
    if (ri.shape.type != NO_SHAPE) shadow = 0.0;
    else shadow = clamp(ri.shadow, .0,1.0);

    return shadow;
}

float ComputeAO(const vec3 p, const vec3 n)
{
    float ao = 0.0;
    
    int   i = 0;
    float r,d;
    while (i<AO_NUM_STEPS)
    {
        i++;
        d = AO_STEP_SIZE * float(i);
    	r = GetNearestShape(p + n*d).dist;
   
        ao += max(0.0, (d-r)/d);
    }
    
    return 1.0 - ao*AO_INTENSITY;
}

void DoTheLighting(RayIntersection ri, out vec4 c)
{
    float attByDst;
    float NoL, specAngle;
    float shadow, ao;
    float d2l = MAX_DISTANCE;
    vec3  diffuse, specular;
    vec3  L, halfVec;
    vec4  ambient;
    
    if (ri.shape.type == MANDELBULB)
    {           
        // Base orbit trap color
        vec3 orbitColor = vec3(0.01);
        orbitColor = mix(orbitColor, vec3(0.6, 0.37, 0.22),
                         clamp(pow(abs(ri.shape.color.y), 1.), 0., 1.));
        orbitColor = mix(orbitColor, vec3(0.6, 0.37, 0.22),
                         clamp(pow(abs(ri.shape.color.z), 1.), 0., 1.));
        orbitColor = mix(orbitColor, vec3(0.1, 0.3, 0.1),
                         clamp(pow(abs(ri.shape.color.w), 16.), 0., 1.));
        
        // Ambient Occlusion
        // NOTE: The orbit trap based AO estimation is more aesthetically pleasing
        //       (and cheaper) than the more precise version I already had in the
        //		 'DoTheLighting' function.
        ao = clamp(0.1 * log(ri.shape.color.x), 0., 1.);
        
        ri.shape.color.rgb = orbitColor;
    }
    else
    {
        ao = ComputeAO(ri.pos, ri.shape.normal.xyz);
    }
    
	for (int i=0; i<NUM_LIGHTS; i++)
    {
        if (scene.lights[i].type == DIRECTIONAL)
        {

            L 		 = -scene.lights[i].dir;
            attByDst = 1.0;
        }
        else if (scene.lights[i].type == POINT)
        {
            vec3  p2l = scene.lights[i].pos - ri.pos;
            d2l = length(p2l); 
            if (d2l > scene.lights[i].range) continue;
            attByDst = (scene.lights[i].range - d2l) /
                		max(scene.lights[i].range, EPSILON);
            L = normalize(p2l);
        }

        // BLINN-PHONG
        // Diffuse component
        NoL      = clamp(dot(L, ri.shape.normal.xyz), .0, 1.0);
        diffuse += NoL * attByDst *
            	   scene.lights[i].color * scene.lights[i].intensity;
        
        // Specular component
        if (NoL >= .0 && ri.shape.glossy > .0)
        {
            halfVec    = normalize(-ri.ray.d + L);
            specAngle  = clamp(dot(ri.shape.normal.rgb, halfVec), .0, 1.0);
            specular  += pow(abs(specAngle), ri.shape.glossy*512.) * attByDst *
                		 scene.lights[i].color * scene.lights[i].intensity;
        }

        shadow += ComputeShadow(ri.pos, ri.shape.normal.xyz, L, d2l);
    }
    
    ambient = vec4(AMBIENT_LIGHT, 1);

    // Combine all the illumination components
    c  = ri.shape.color * vec4(diffuse, 1);
    c *= shadow * ao;
    c += ri.shape.color * ambient;
	c += vec4(specular, 0);
    
    // DEBUG: Normals
    //c = ri.shape.normal;
    // DEBUG: Ambient Occlusion
    //c = vec4(ao,ao*.5,0,1);
    
    // NOTE: Applying the fog here keeps the sky gradient,
    // but makes the horizon look too sharp
	//ApplyFog(c.rgb, ri.distance);
}

vec3 ComputeReflection(inout Ray r, const float g)
{
    RayIntersection ri = CastRay(r, MAX_REFLECTION_DIST);
    
    r = ri.ray;
    
    vec4 o = vec4(BLACK,1);
    DoTheLighting(ri, o);
    
    return mix(BLACK, o.rgb, g).rgb * REFLECTION_INTENSITY * g;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    SceneInit(scene);
    
    vec2 uv = NormalizeScreenCoords(fragCoord);
    Ray ray = GetCameraRay(scene.cam, uv);
    
    RayIntersection ri = CastRay(ray, MAX_DISTANCE);
    
	if (ri.shape.type != NO_SHAPE)
    { // Illuminate the object
        DoTheLighting(ri, fragColor);
    }
    else
    { // Sky
        fragColor.rgb = mix(TEAL, SKY_COLOR, uv.y);
    }
    
	// "Mist"
    fragColor.rgb += vec3(float(ri.numIt)/float(MAX_ITERATIONS)) *
        			 FOG_DENSITY * FOG_COLOR;
    
    // Gamma
    fragColor.rgb  = sqrt(fragColor.rgb);
    // Vignette
    fragColor.rgb *= 1. - VIGNETTE_STR * length(uv);
    
    // Just in case
    fragColor.w = 1.;
}