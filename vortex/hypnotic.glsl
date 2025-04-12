void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = (fragCoord-0.5*iResolution.xy)/iResolution.y;

    float t = iTime * .2;

    vec3 ro = vec3(0, 0, -1);
    vec3 lookat = vec3(0);
    float zoom = mix(.2, .7, sin(t * 10.) * .5 + .7);
    
    vec3 f = normalize(lookat - ro),
        r = normalize(cross(vec3(0, 1, 0), f)),
        u = cross(f, r),
        c = ro + f * zoom,
        i = c + uv.x * r + uv.y * u,
        rd = normalize(i-ro);
    
   
    float dS, dO;
    vec3 p;
    
    for(int i = 0; i<100; i++)
    {
        p = ro + rd * dO;
        dS = -(length(vec2(length(p.xz) - 1., p.y)) - .75);//dist function of torus
        if(dS < .001) break;
        dO += dS;
    }
    
    //vec3 col = vec3(1.000,0.424,0.278);
    vec3 col = vec3(0.000,0.000,0.000);
    
    if(dS < .001)
    {
        float x = atan(p.x, p.z) + t;               //-pi to pi
        float y = atan(length(p.xz)-1., p.y);
        
        float bands = sin(y * 10. + x * 30.);
        
        float ripples = sin((x * 10. + -y * 30.) * 3.) * .5 + .5;
        
        float waves = sin(x * 2. + -y * 6. + t*40.);
        
        float b1 = smoothstep(-.2, .2, bands);
        float b2 = smoothstep(-.2, .2, bands - 0.5);
        
        float m = b1 * (1. -b2);
        m += max(m, ripples * b2 * max(0., waves));
        m += max(0., waves) * b2;
        //col += 1. - m;
        col += mix(m, 1.-m, smoothstep(-.3, .3, sin(x *2. + t)));
    }

    // Output to screen
    fragColor = vec4(col,1.0);
}