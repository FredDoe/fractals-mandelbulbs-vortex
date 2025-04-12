import taichi as ti
import taichi.math as tm
import time

ti.init(arch=ti.gpu)

# Constants
DIST_FAR = 6.0
ITERATIONS = 4
WIDTH, HEIGHT = 800, 600

# Taichi fields
image = ti.Vector.field(3, dtype=ti.f32, shape=(WIDTH, HEIGHT))

@ti.func
def calcfractal(coord):
    orbit = coord
    dz = 1.0
    
    for i in range(ITERATIONS):
        r = tm.length(orbit)
        if r == 0.0:
            break
        
        # Spherical coordinates
        theta = tm.acos(orbit.z / r)
        phi = tm.atan2(orbit.y, orbit.x)
        
        # Derivative calculation
        dz = 8.0 * (r**7) * dz + 1.0
        
        # Power-8 transformation
        r = r**8
        theta *= 8.0
        phi *= 8.0
        
        # Convert back to cartesian
        x = r * tm.sin(theta) * tm.cos(phi)
        y = r * tm.sin(theta) * tm.sin(phi)
        z = r * tm.cos(theta)
        orbit = tm.vec3(x, y, z) + coord
        
        if tm.dot(orbit, orbit) > 4.0:
            break
    
    z = tm.length(orbit)
    return 0.5 * z * tm.log(z) / dz if dz != 0 else 0.0

@ti.func
def map(p):
    return tm.vec2(calcfractal(p.xzy), 1.0)  # Swapped y/z

@ti.func
def trace(ro, rd):
    t = 0.0
    result = tm.vec3(0.0)
    
    for i in range(1000):
        if t > DIST_FAR:
            break
        
        pos = ro + t * rd
        h = map(pos)
        
        if h.x < 1e-4:
            result = tm.vec3(t, h.y, float(i))
            break
        
        t += h.x
    
    return result

@ti.func
def calcnormal(p, eps=1e-4):
    e = tm.vec3(eps, 0, 0)
    return tm.normalize(tm.vec3(
        map(p + e.xyy).x - map(p - e.xyy).x,
        map(p + e.yxy).x - map(p - e.yxy).x,
        map(p + e.yyx).x - map(p - e.yyx).x
    ))

@ti.func
def softshadow(ro, rd):
    res = 1.0
    t = 0.01
    
    for i in range(1000):
        if t > 1.0:
            break
        
        pos = ro + t * rd
        h = map(pos)
        
        if h.x < 1e-4:
            res = 0.0
            break
        
        res = tm.min(res, 4.0 * h.x / t)
        t += h.x
    
    return res

@ti.kernel
def render(time: ti.f32):
    for x, y in image:
        uv = tm.vec2(
            (x / WIDTH) * 2.0 - 1.0,
            (y / HEIGHT) * 2.0 - 1.0
        )
        uv.x *= WIDTH / HEIGHT
        
        # Camera setup
        ro = tm.vec3(0.0, 0.0, -1.4)
        rd = tm.normalize(tm.vec3(uv, 1.5))
        
        # Camera animation
        theta = 1.5 * tm.sin(time/30.0 - 1.0)
        rm1 = tm.mat2(tm.cos(theta), tm.sin(theta), 
                     -tm.sin(theta), tm.cos(theta))
        rd.yz = rm1 @ rd.yz
        ro.yz = rm1 @ ro.yz
        
        theta = time/20.0
        rm2 = tm.mat2(tm.cos(theta), tm.sin(theta), 
                     -tm.sin(theta), tm.cos(theta))
        rd.xz = rm2 @ rd.xz
        ro.xz = rm2 @ ro.xz
        
        # Ray marching
        t_result = trace(ro, rd)
        col = tm.vec3(0.8)
        
        if t_result.z > 0.0:
            pos = ro + rd * t_result.x
            nor = calcnormal(pos)
            lig = tm.normalize(tm.vec3(0.3, 1.0, 0.3))
            
            # Lighting calculations
            occ = 1.0 / (1.0 + pow(t_result.z/30.0, 3.0))
            sha = softshadow(pos, lig)
            dif = tm.max(0.0, tm.dot(lig, nor))
            sky = tm.max(0.0, nor.y)
            ind = tm.max(0.0, tm.dot(-lig, nor))
            ref = tm.reflect(rd, nor)
            spec = tm.pow(tm.max(0.0, tm.dot(ref, lig)), 20.0)
            
            # Combine lighting
            col = dif * tm.vec3(0.9, 0.8, 0.7) * sha
            col += sky * tm.vec3(0.16, 0.20, 0.24) * occ
            col += ind * tm.vec3(0.40, 0.48, 0.40) * occ
            col += 0.1 * occ
            col += spec * sha * tm.vec3(0.9, 0.8, 0.7)
            
            # Gamma correction
            col = tm.pow(col, tm.vec3(0.45))
        
        image[x, y] = col

# Interactive visualization
gui = ti.GUI("Fractal Render", res=(WIDTH, HEIGHT))

start_time = time.time()
while gui.running:
    current_time = time.time() - start_time
    render(current_time)
    gui.set_image(image)
    gui.show()