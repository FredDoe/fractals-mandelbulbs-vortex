# FRACTALS AND CHAOS MEET RECURSION: 2D FRACTALS, MANDELBULBS, AND VORTEX

## Programming Languages and Tools Required for Project
 - Python
 - GLSL
 - Taichi
 - Shadertoy [Access Here](https://www.shadertoy.com/)

## VSCode Extensions Required for GLSL Files Locally (Optional if you will use the shadertoy online platform)
It is however recommended to run the `.glsl` files on the  `Shadertoy` online platform. 
Just copy and paste the code as a new shader to see the shapes.

- WebGL GLSL Editor
- GLSL Canvas (glsl-canvas)


## Virtual Environment
Create a virtual environment for the project. The required dependencies will be installed into this environment.
While in the project's root directory, do this:

### On Windows OS
Create a virtual environment on Windows

```
python -m venv venv
```

#### Activate the virtual environment
Activate the virtual environment to install the project-specific dependencies.

##### Using BASH terminal
```
source venv/Scripts/activate
```

##### Using CMD terminal
``` 
venv\Scripts\activate
```

### On Linux OS
Create a virtual environment on Windows

```
python3 -m venv venv
```

#### Activate the virtual environment
Activate the virtual environment to install the project-specific dependencies.

```
source venv/bin/activate
```

## Install Dependencies
Run the following command to install the required dependencies. This must be done while the virtual environment is still activated.
```
pip install -r requirements.txt
```

## Running the Python files
While in the project directory, you can run any of the python files to see the implemented shapes using
```
python <directory>/<filename.py>
```

- `<directory>` is an placeholder argument for any of the directories (2d_fractals | mandelbulbs | vortex) in the project directory
- `<filename.py>` is a placeholder argument which refers to any of the python files you want to run


