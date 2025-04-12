// https://youtube.com/shorts/RMB6iJB3KfY?feature=share
vec3 palette(float d) {
    return mix(vec3(0.1, 0.5, 0.7), vec3(0.9, 0.2, 0.6), d);
}

vec2 rotate(vec2 p, float a) {
    float c = cos(a);
    float s = sin(a);
    return p * mat2(c, s, -s, c);
}

float map(vec3 p) {
    for (int i = 0; i < 10; ++i) {
        float t = iTime * 0.3;
        p.xz = rotate(p.xz, t);
        p.xy = rotate(p.xy, t * 1.5);
        p.xz = abs(p.xz);
        p.xz -= 0.5;
    }
    return length(p) - 0.5;
}

vec4 rm(vec3 ro, vec3 rd) {
    float t = 0.0;
    vec3 col = vec3(0.0);
    float d;
    for (float i = 0.0; i < 128.0; i++) {
        vec3 p = ro + rd * t;
        d = map(p);
        if (d < 0.01) {
            break;
        }
        if (d > 100.0) {
            break;
        }
        col += palette(length(p) * 0.1) / (400.0 * d);
        t += d;
    }
    return vec4(col, 1.0 / (d * 100.0));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - (iResolution.xy / 2.0)) / iResolution.x;
    vec3 ro = vec3(0.0, 0.0, -50.0);
    ro.xz = rotate(ro.xz, iTime);
    vec3 cf = normalize(-ro);
    vec3 cs = normalize(cross(cf, vec3(0.0, 1.0, 0.0)));
    vec3 cu = normalize(cross(cf, cs));

    vec3 uuv = ro + cf * 3.0 + uv.x * cs + uv.y * cu;

    vec3 rd = normalize(uuv - ro);

    vec4 col = rm(ro, rd);

    fragColor = col;
}