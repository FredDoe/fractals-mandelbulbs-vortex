const float PI = 3.14159265358979323846264;
const float TWOPI = PI*2.0;
const vec4 WHITE = vec4(1.0, 1.0, 1.0, 1.0);
const vec4 BLACK = vec4(0.0, 0.0, 0.0, 1.0);
const int MAX_RINGS = 30;
const float RING_DISTANCE = 0.05;
const float WAVE_COUNT = 60.0;
const float WAVE_DEPTH = 0.04;

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    float rot = mod(iTime*0.6, TWOPI);
    vec2 pos = vec2(fragCoord.x / iResolution.x, fragCoord.y / iResolution.y);
    pos = vec2(3.0*(pos.x - 0.5), 2.0*(pos.y - 0.5));
    float x = pos.x;
    float y = pos.y;

    bool black = false;
    float prevRingDist = RING_DISTANCE;
    for (int i = 0; i < MAX_RINGS; i++) {
        vec2 center = vec2(0.0, 0.7 - RING_DISTANCE * float(i)*1.2);
        float radius = 0.5 + RING_DISTANCE / (pow(float(i+5), 1.1)*0.006);
        float dist = distance(center, pos);
        dist = pow(dist, 0.3);
        float ringDist = abs(dist-radius);
        if (ringDist < RING_DISTANCE*prevRingDist*7.0) {
            float angle = atan(y - center.y, x - center.x);
            float thickness = 1.1 * abs(dist - radius) / prevRingDist;
            float depthFactor = WAVE_DEPTH * sin((angle+rot*radius) * WAVE_COUNT);
            if (dist > radius) {
                black = (thickness < RING_DISTANCE * 5.0 - depthFactor * 2.0);
            }
            else {
                black = (thickness < RING_DISTANCE * 5.0 + depthFactor);
            }
            break;
        }
        if (dist > radius) break;
        prevRingDist = ringDist;
    }

    fragColor = black ? BLACK : WHITE;
}