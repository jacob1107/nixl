## Build options

### Build & install in a conda environment
Refer to [README.md](../README.md) for instructions on how to install prerequisites.
```
$ conda activate <ENV_NAME>

$ meson setup nixl-build --prefix=<PATH_TO_CONDA_ENV>
$ cd nixl-build
$ ninja
$ ninja install

$ cd ..
$ pip install .
$ pip list | grep nixl
$ python -c "from nixl._api import nixl_agent; print('Success')"
```
