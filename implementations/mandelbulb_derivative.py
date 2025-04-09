import taichi as ti
import math

ti.init(arch=ti.gpu)

AA = 1  # Set to 1, 2, or 3 based on performance needs
res = (800, 600)
img = ti.Vector.field(3, ti.f32, shape=res)
light1 = ti.Vector([0.577, 0.577, -0.577])
light2 = ti.Vector([-0.707, 0.000, 0.707])

@ti.func
def isphere(sph, ro, rd):
    oc = ro - sph.xyz
    b = oc.dot(rd)
    c = oc.dot(oc) - sph.w**2
    h = b**2 - c
    result = ti.Vector([-1.0, -1.0])
    if h >= 0.0:
        h = ti.sqrt(h)
        result = ti.Vector([-b - h, -b + h])
    return result

@ti.func
def map(p, resColor):
    w = p
    m = w.dot(w)
    trap = ti.Vector([abs(w).x, abs(w).y, abs(w).z, m])
    dz = 1.0
    
    for i in range(4):
        dz = 8.0 * (m**3.5) * dz + 1.0
        r = ti.sqrt(w.dot(w))
        b = 8.0 * ti.acos(w.y / r)
        a = 8.0 * ti.atan2(w.z, w.x)
        sin_b = ti.sin(b)
        w = p + (r**8.0) * ti.Vector([sin_b * ti.sin(a), ti.cos(b), sin_b * ti.cos(a)])
        trap = ti.min(trap, ti.Vector([abs(w).x, abs(w).y, abs(w).z, m]))
        m = w.dot(w)
        if m > 256.0:
            break
    
    resColor = ti.Vector([m, trap.y, trap.z, trap.w])
    return 0.25 * ti.log(m) * ti.sqrt(m) / dz

@ti.func
def calcNormal(pos, t, px):
    eps = 0.5773 * 0.25 * px
    e = ti.Vector([eps, -eps])
    tmp = ti.Vector([0.0, 0.0, 0.0, 0.0])
    
    n = (e.xyy * map(pos + e.xyy, tmp) +
         e.yyx * map(pos + e.yyx, tmp) +
         e.yxy * map(pos + e.yxy, tmp) +
         e.xxx * map(pos + e.xxx, tmp))
    return n.normalized()

@ti.func
def softshadow(ro, rd, k):
    sph = ti.Vector([0.0, 0.0, 0.0, 1.25])
    dis = isphere(sph, ro, rd)
    tmax = dis.y
    res = 1.0
    t = 0.0
    for i in range(64):
        if t >= tmax:
            break
        h = 0.0
        tmp = ti.Vector([0.0, 0.0, 0.0, 0.0])
        h = map(ro + rd * t, tmp)
        res = ti.min(res, k * h / t)
        if res < 0.001:
            break
        t += ti.clamp(h, 0.01, 0.2)
    return ti.clamp(res, 0.0, 1.0)

@ti.func
def raycast(ro, rd, rescol, px):
    sph = ti.Vector([0.0, 0.0, 0.0, 1.25])
    dis = isphere(sph, ro, rd)
    res = -1.0
    if dis.y > 0.0:
        dis.x = ti.max(dis.x, 0.0)
        dis.y = ti.min(dis.y, 10.0)
        t = dis.x
        trap = ti.Vector([0.0, 0.0, 0.0, 0.0])
        for i in range(128):
            pos = ro + rd * t
            th = 0.25 * px * t
            h = map(pos, trap)
            if t > dis.y or h < th:
                break
            t += h
        if t < dis.y:
            rescol = trap
            res = t
    return res

@ti.func
def render(p, cam, iResolution):
    fle = 1.5
    sp = (2.0 * p - iResolution) / iResolution.y
    px = 2.0 / (iResolution.y * fle)
    
    ro = ti.Vector([cam[0, 3], cam[1, 3], cam[2, 3]])
    rd = (cam @ ti.Vector([sp.x, sp.y, fle, 0.0])).xyz.normalized()
    
    rescol = ti.Vector([0.0, 0.0, 0.0, 0.0])
    t = raycast(ro, rd, rescol, px)
    col = ti.Vector([0.0, 0.0, 0.0])
    
    if t < 0.0:
        col = ti.Vector([0.8, 0.9, 1.1]) * (0.6 + 0.4 * rd.y)
        col += 5.0 * ti.Vector([0.8, 0.7, 0.5]) * ti.pow(ti.max(ti.dot(rd, light1), 0.0), 32)
    else:
        col = ti.Vector([0.01])
        col = ti.mix(col, ti.Vector([0.10, 0.20, 0.30]), ti.clamp(rescol.y, 0.0, 1.0))
        col = ti.mix(col, ti.Vector([0.02, 0.10, 0.30]), ti.clamp(rescol.z**2, 0.0, 1.0))
        col = ti.mix(col, ti.Vector([0.30, 0.10, 0.02]), ti.clamp(rescol.w**6, 0.0, 1.0))
        col *= 0.5
        
        pos = ro + t * rd
        nor = calcNormal(pos, t, px)
        nor = nor * (1 - 2 * (ti.dot(nor, -rd) < 0))
        
        hal = (light1 - rd).normalized()
        ref = rd - 2 * nor.dot(rd) * nor
        occ = ti.clamp(0.05 * ti.log(rescol.x), 0.0, 1.0)
        fac = ti.clamp(1.0 + rd.dot(nor), 0.0, 1.0)
        
        sha1 = softshadow(pos + 0.001 * nor, light1, 32.0)
        dif1 = ti.clamp(light1.dot(nor), 0.0, 1.0) * sha1
        spe1 = ti.pow(ti.clamp(nor.dot(hal), 0.0, 1.0), 32) * dif1 * (0.04 + 0.96 * ti.pow(1.0 - hal.dot(light1), 5))
        dif2 = ti.clamp(0.5 + 0.5 * light2.dot(nor), 0.0, 1.0) * occ
        dif3 = (0.7 + 0.3 * nor.y) * (0.2 + 0.8 * occ)
        
        lin = ti.Vector([0.0, 0.0, 0.0])
        lin += 12.0 * ti.Vector([1.50, 1.10, 0.70]) * dif1
        lin += 4.0 * ti.Vector([0.25, 0.20, 0.15]) * dif2
        lin += 1.5 * ti.Vector([0.10, 0.20, 0.30]) * dif3
        lin += 2.5 * ti.Vector([0.35, 0.30, 0.25]) * (0.05 + 0.95 * occ)
        lin += 4.0 * fac * occ
        col *= lin
        col = ti.pow(col, ti.Vector([0.7, 0.9, 1.0]))
        col += spe1 * 15.0
    
    col = ti.pow(col, ti.Vector([1/2.2, 1/2.2, 1/2.2]))
    col *= 1.0 - 0.05 * ti.sqrt(sp.dot(sp))
    return col

@ti.kernel
def main_image(iTime: ti.f32, iResolution: ti.types.vector(2, ti.f32)):
    time = iTime * 0.1
    di = 1.4 + 0.1 * ti.cos(0.29 * time)
    ro = di * ti.Vector([
        ti.cos(0.33 * time),
        0.8 * ti.sin(0.37 * time),
        ti.sin(0.31 * time)
    ])
    ta = ti.Vector([0.0, 0.1, 0.0])
    cr = 0.5 * ti.cos(0.1 * time)
    
    cp = ti.Vector([ti.sin(cr), ti.cos(cr), 0.0])
    cw = (ta - ro).normalized()
    cu = cp.cross(cw).normalized()
    cv = cw.cross(cu)
    cam = ti.Matrix.zero(ti.f32, 4, 4)
    cam[0, :3] = cu
    cam[1, :3] = cv
    cam[2, :3] = cw
    cam[0, 3] = ro.x
    cam[1, 3] = ro.y
    cam[2, 3] = ro.z
    cam[3, 3] = 1.0
    
    for i, j in img:
        col = ti.Vector([0.0, 0.0, 0.0])
        for si, sj in ti.static(ti.ndrange(AA, AA)):
            p = ti.Vector([i + (si + 0.5)/AA, j + (sj + 0.5)/AA])
            col += render(p, cam, iResolution)
        col /= AA**2
        img[i, j] = col

if __name__ == "__main__":
    gui = ti.GUI("Mandelbulb", res)
    iTime = 0.0
    while gui.running:
        main_image(iTime, ti.Vector(res))
        gui.set_image(img)
        gui.show()
        iTime += 0.1