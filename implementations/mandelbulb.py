import taichi as ti

ti.init(arch=ti.cpu)
n = 120
pixels = ti.Vector.field(3, dtype=float, shape=(n, n, n))
# Define particles and colors as 1D fields
particles = ti.Vector.field(3, float, shape=n**3)
colors = ti.Vector.field(3, float, shape=n**3)


@ti.func
def vector_power_n(v, n):
    r = v.norm()
    theta = ti.atan2(v.z, ti.sqrt(v.x**2 + v.y**2))
    phi = ti.atan2(v.y, v.x)
    return (
        ti.Vector(
            [
                ti.cos(n * phi) * ti.cos(n * theta),
                ti.sin(n * phi) * ti.cos(n * theta),
                ti.sin(n * theta),
            ]
        )
        * r**n
    )


@ti.kernel
def paint(t: float):
    for l, m, k in pixels:
        # Calculate the flattened index correctly
        idx = l + m * n + k * n * n

        c = ti.Vector([ti.sin(t) * 50, -ti.sin(t) * 150 + 10, -ti.cos(t) * 200])
        v = ti.Vector([4 * l / n - 2, 4 * m / n - 2, 4 * k / n - 2])
        iterations = 0
        while v.norm() > 2 and iterations < 256:
            v = vector_power_n(v, 8) + c
            iterations += 1
        colors[idx] = ti.Vector([iterations / 300, iterations / 200, iterations / 300])
        if iterations > 255:
            particles[idx] = ti.Vector([4 * l / n - 2, 4 * m / n - 2, 4 * k / n - 2])
        else:
            particles[idx] = ti.Vector([0, 0, 0])


window = ti.ui.Window("Fractal 3D", (n, n), vsync=True)
canvas = window.get_canvas()
scene = window.get_scene()
camera = ti.ui.make_camera()

# Better frame rate management
try:
    for i in range(100000):
        paint(i * 0.01)
        camera.position(-3, -3, 6)
        camera.lookat(0, 0, 0)
        camera.up(0, 1, 0)
        scene.set_camera(camera)
        scene.point_light(pos=(0.5, 1, 2), color=(1, 1, 1))
        scene.point_light(pos=(0.5, -1, 2), color=(1, 1, 1))

        # Use the correct format for particles with per_vertex_color
        scene.particles(particles, radius=0.015, per_vertex_color=colors)
        scene.ambient_light((0.1, 0.1, 0.1))

        canvas.scene(scene)
        window.show()
except KeyboardInterrupt:
    print("Exiting program due to user interrupt")
