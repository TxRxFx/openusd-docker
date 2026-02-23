name = "python"
version = "3.10.14"
description = "Python 3.10.14 runtime compiled from source for OpenUSD"

variants = [
    ["platform-linux", "arch-x86_64"],
]


def commands():
    root = "{root}"
    env.PATH.prepend("{}/bin".format(root))
    env.LD_LIBRARY_PATH.prepend("{}/lib".format(root))
    env.PYTHONHOME.set(root)
