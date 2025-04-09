import taichi as ti
import numpy as np
import math

# Initialize Taichi
ti.init(arch=ti.auto)  # Auto-select the best available backend

# Configuration
width = 800
height = 600
aa_level = 2  # Anti-aliasing level

# Allocate pixels array
pixels = ti.field(dtype=ti.f32, shape=(width, height, 3))  # RGB values

@ti.func
def vector_length(v):
    """Calculate the length of a vector"""
    return ti.sqrt(v[0]*v[0] + v[1]*v[1] + v[2]*v[2])

@ti.func
def normalize_vector(v):
    """Normalize a vector"""
    length = vector_length(v)
    return ti.Vector([v[0]/length, v[1]/length, v[2]/length])

@ti.func
def dot_product(a, b):
    """Calculate dot product of two vectors"""
    return a[0]*b[0] + a[1]*b[1] + a[2]*b[2]

@ti.func
def cross_product(a, b):
    """Calculate cross product of two vectors"""
    return ti.Vector([
        a[1]*b[2] - a[2]*b[1],
        a[2]*b[0] - a[0]*b[2],
        a[0]*b[1] - a[1]*b[0]
    ])

@ti.func
def ray_sphere_intersection(sphere_center, sphere_radius, ray_origin, ray_dir):
    """Ray-sphere intersection test"""
    oc = ray_origin - sphere_center
    b = dot_product(oc, ray_dir)
    c = dot_product(oc, oc) - sphere_radius*sphere_radius
    h = b*b - c
    
    result = ti.Vector([-1.0, -1.0])  # Default to no intersection
    
    if h >= 0.0:
        h = ti.sqrt(h)
        result = ti.Vector([-b-h, -b+h])
        
    return result

@ti.func
def mandelbulb_distance(p, trap):
    """Distance estimation function for Mandelbulb fractal"""
    w = ti.Vector([p[0], p[1], p[2]])
    m = dot_product(w, w)
    
    # Initialize trap values for coloring
    trap[0] = m
    trap[1] = ti.abs(w[1])
    trap[2] = ti.abs(w[2])
    trap[3] = ti.abs(w[0])
    
    dz = 1.0
    
    for i in range(4):  # Number of iterations
        # Calculate distance
        r = vector_length(w)
        if r > 0.0:  # Avoid division by zero
            b = 8.0 * ti.acos(w[1] / r)
            a = 8.0 * ti.atan2(w[0], w[2])
            
            r_pow8 = ti.pow(r, 8.0)
            sin_b = ti.sin(b)
            
            # Mandelbulb formula
            w = ti.Vector([
                p[0] + r_pow8 * sin_b * ti.sin(a),
                p[1] + r_pow8 * ti.cos(b),
                p[2] + r_pow8 * sin_b * ti.cos(a)
            ])
        
        # Update distance estimator derivative
        dz = 8.0 * ti.pow(m, 3.5) * dz + 1.0
        
        # Update trap values for coloring
        trap[1] = ti.min(trap[1], ti.abs(w[1]))
        trap[2] = ti.min(trap[2], ti.abs(w[2]))
        trap[3] = ti.min(trap[3], ti.abs(w[0]))
        
        # Update squared length for next iteration
        m = dot_product(w, w)
        trap[0] = m
        
        # Escape condition
        if m > 256.0:
            break
    
    # Distance estimation through the Hubbard-Douady potential
    return 0.25 * ti.log(m) * ti.sqrt(m) / dz

@ti.func
def calculate_normal(pos, px):
    """Calculate normal at surface point using central differences"""
    # Gradient calculation using central differences
    eps = 0.5773 * 0.25 * px
    
    # Create offset vectors
    e1 = ti.Vector([eps, -eps, -eps])
    e2 = ti.Vector([-eps, -eps, eps])
    e3 = ti.Vector([-eps, eps, -eps])
    e4 = ti.Vector([eps, eps, eps])
    
    trap = ti.Vector([0.0, 0.0, 0.0, 0.0])
    
    # Calculate the gradient using central differences
    return normalize_vector(ti.Vector([
        mandelbulb_distance(pos + e1, trap) - mandelbulb_distance(pos - e1, trap),
        mandelbulb_distance(pos + e2, trap) - mandelbulb_distance(pos - e2, trap),
        mandelbulb_distance(pos + e3, trap) - mandelbulb_distance(pos - e3, trap)
    ]))

@ti.func
def soft_shadow(ray_origin, ray_dir, k):
    """Calculate soft shadows"""
    # Bounding sphere for optimization
    sphere_center = ti.Vector([0.0, 0.0, 0.0])
    sphere_radius = 1.25
    
    t_bounds = ray_sphere_intersection(sphere_center, sphere_radius, ray_origin, ray_dir)
    tmax = t_bounds[1]
    
    result = 1.0
    t = 0.01  # Start a bit away from surface
    
    # Shadow ray marching
    for i in range(64):
        if t >= tmax:
            break
            
        # Calculate distance to surface
        trap = ti.Vector([0.0, 0.0, 0.0, 0.0])
        h = mandelbulb_distance(ray_origin + ray_dir * t, trap)
        
        # Accumulate shadow factor
        result = ti.min(result, k * h / t)
        
        if result < 0.001:
            break
            
        t += ti.clamp(h, 0.01, 0.2)
    
    return ti.clamp(result, 0.0, 1.0)

@ti.func
def ray_cast(ray_origin, ray_dir, px):
    """Cast a ray and find intersection with the fractal"""
    # Initial values
    t = -1.0  # Hit distance
    trap = ti.Vector([0.0, 0.0, 0.0, 0.0])  # Trap coloring info
    
    # Bounding sphere test for optimization
    sphere_center = ti.Vector([0.0, 0.0, 0.0])
    sphere_radius = 1.25
    
    bounds = ray_sphere_intersection(sphere_center, sphere_radius, ray_origin, ray_dir)
    
    # If ray hits bounding sphere
    if bounds[1] >= 0.0:
        t_min = ti.max(bounds[0], 0.0)  # Start at entry point or ray origin
        t_max = ti.min(bounds[1], 10.0)  # Cap maximum distance
        
        # Ray marching
        t_current = t_min
        
        for i in range(128):  # Maximum steps
            pos = ray_origin + ray_dir * t_current
            hit_threshold = 0.25 * px * t_current  # Threshold based on distance
            
            h = mandelbulb_distance(pos, trap)
            
            # Break if hit or exceeded bounds
            if h < hit_threshold or t_current > t_max:
                break
                
            t_current += h  # Step forward
        
        # If within bounds, record hit
        if t_current < t_max:
            t = t_current
    
    return t, trap

@ti.kernel
def render(t: ti.f32):
    """Render a frame at time t"""
    # Camera setup
    time = t * 0.1
    
    # Camera parameters - orbiting motion
    distance = 1.4 + 0.1 * ti.cos(0.29 * time)
    camera_pos = ti.Vector([
        distance * ti.cos(0.33 * time),
        distance * 0.8 * ti.sin(0.37 * time),
        distance * ti.sin(0.31 * time)
    ])
    camera_target = ti.Vector([0.0, 0.1, 0.0])
    
    # Camera roll
    cam_roll = 0.5 * ti.cos(0.1 * time)
    
    # Light directions
    light1 = normalize_vector(ti.Vector([0.577, 0.577, -0.577]))
    light2 = normalize_vector(ti.Vector([-0.707, 0.000, 0.707]))
    
    # Process each pixel
    for i, j in ti.ndrange(width, height):
        # Final color for the pixel
        pixel_color = ti.Vector([0.0, 0.0, 0.0])
        
        # Anti-aliasing loop
        for aa_i in range(aa_level):
            for aa_j in range(aa_level):
                # Calculate normalized device coordinates with anti-aliasing offset
                u = (2.0 * (i + (aa_i + 0.5) / aa_level) - width) / height
                v = (2.0 * (j + (aa_j + 0.5) / aa_level) - height) / height
                
                # Camera basis vectors
                cam_dir = normalize_vector(camera_target - camera_pos)
                cam_side = normalize_vector(cross_product(
                    cam_dir, 
                    ti.Vector([ti.sin(cam_roll), ti.cos(cam_roll), 0.0])
                ))
                cam_up = cross_product(cam_side, cam_dir)
                
                # Ray direction
                focal_length = 1.5
                ray_dir = normalize_vector(
                    u * cam_side + v * cam_up + focal_length * cam_dir
                )
                
                # Ray casting
                hit_dist, trap = ray_cast(camera_pos, ray_dir, 2.0 / (height * focal_length))
                
                # Pixel color calculation
                sample_color = ti.Vector([0.0, 0.0, 0.0])
                
                # Sky color if no hit
                if hit_dist < 0.0:
                    # Basic sky gradient
                    sky_color = ti.Vector([0.8, 0.9, 1.1]) * (0.6 + 0.4 * ray_dir[1])
                    
                    # Sun highlight
                    sun_intensity = ti.pow(ti.max(0.0, dot_product(ray_dir, light1)), 32.0)
                    sky_color += 5.0 * ti.Vector([0.8, 0.7, 0.5]) * sun_intensity
                    
                    sample_color = sky_color
                else:
                    # Fractal surface hit
                    
                    # Base color from trap values
                    col = ti.Vector([0.01, 0.01, 0.01])
                    col = col * (1.0 - ti.min(1.0, trap[1])) + ti.Vector([0.10, 0.20, 0.30]) * ti.min(1.0, trap[1])
                    col = col * (1.0 - ti.min(1.0, trap[2] * trap[2])) + ti.Vector([0.02, 0.10, 0.30]) * ti.min(1.0, trap[2] * trap[2])
                    col = col * (1.0 - ti.min(1.0, ti.pow(trap[3], 6.0))) + ti.Vector([0.30, 0.10, 0.02]) * ti.min(1.0, ti.pow(trap[3], 6.0))
                    col *= 0.5
                    
                    # Surface position and normal
                    hit_pos = camera_pos + hit_dist * ray_dir
                    normal = calculate_normal(hit_pos, 2.0 / (height * focal_length))
                    
                    # Flip normal if needed for back-facing surfaces
                    if dot_product(ray_dir, normal) > 0.0:
                        normal = -normal
                    
                    # Lighting vectors
                    half_vec = normalize_vector(light1 - ray_dir)
                    reflect_vec = ray_dir - 2.0 * normal * dot_product(ray_dir, normal)
                    
                    # Ambient occlusion approximation from trap value
                    occlusion = ti.clamp(0.05 * ti.log(trap[0]), 0.0, 1.0)
                    
                    # Fresnel-like factor
                    fresnel = ti.clamp(1.0 + dot_product(ray_dir, normal), 0.0, 1.0)
                    
                    # Lighting components
                    
                    # Direct sun light with shadows
                    shadow = soft_shadow(hit_pos + 0.001 * normal, light1, 32.0)
                    diffuse1 = ti.max(0.0, dot_product(light1, normal)) * shadow
                    
                    # Specular highlight
                    specular = ti.pow(ti.max(0.0, dot_product(normal, half_vec)), 32.0) * diffuse1
                    specular *= (0.04 + 0.96 * ti.pow(ti.max(0.0, 1.0 - dot_product(half_vec, light1)), 5.0))
                    
                    # Bounce light
                    diffuse2 = ti.clamp(0.5 + 0.5 * dot_product(light2, normal), 0.0, 1.0) * occlusion
                    
                    # Sky light
                    diffuse3 = (0.7 + 0.3 * normal[1]) * (0.2 + 0.8 * occlusion)
                    
                    # Combine lighting
                    lighting = ti.Vector([0.0, 0.0, 0.0])
                    lighting += 12.0 * ti.Vector([1.50, 1.10, 0.70]) * diffuse1  # Sun
                    lighting += 4.0 * ti.Vector([0.25, 0.20, 0.15]) * diffuse2   # Bounce
                    lighting += 1.5 * ti.Vector([0.10, 0.20, 0.30]) * diffuse3   # Sky
                    lighting += 2.5 * ti.Vector([0.35, 0.30, 0.25]) * (0.05 + 0.95 * occlusion)  # Ambient
                    lighting += 4.0 * fresnel * occlusion  # Fresnel/rim
                    
                    # Apply lighting to color
                    col *= lighting
                    
                    # Color correction
                    col[0] = ti.pow(col[0], 0.7)
                    col[1] = ti.pow(col[1], 0.9)
                    col[2] = ti.pow(col[2], 1.0)
                    
                    # Add specular highlight
                    col += specular * 15.0
                    
                    sample_color = col
                
                # Gamma correction
                sample_color[0] = ti.pow(sample_color[0], 0.4545)
                sample_color[1] = ti.pow(sample_color[1], 0.4545)
                sample_color[2] = ti.pow(sample_color[2], 0.4545)
                
                # Vignette effect
                vignette = 1.0 - 0.05 * ti.sqrt(u*u + v*v)
                sample_color *= vignette
                
                # Accumulate for anti-aliasing
                pixel_color += sample_color
        
        # Average the anti-aliased samples
        pixel_color /= (aa_level * aa_level)
        
        # Store pixel color
        pixels[i, j, 0] = pixel_color[0]  # R
        pixels[i, j, 1] = pixel_color[1]  # G
        pixels[i, j, 2] = pixel_color[2]  # B

# Main function to run the renderer
def main():
    # Create a window
    gui = ti.GUI("Taichi Mandelbulb", res=(width, height))
    
    # Animation loop
    frame = 0
    while gui.running:
        # Render the current frame
        t = frame * 0.03
        render(t)
        
        # Convert pixels to numpy array for display
        img = pixels.to_numpy()
        gui.set_image(img)
        gui.show()
        
        frame += 1

if __name__ == "__main__":
    main()