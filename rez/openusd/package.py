name = "openusd"
version = "25.05.1"
description = "OpenUSD 25.05.1 runtime and tools"

requires = [
    "python-3.10.14",
]

variants = [
    ["platform-linux", "arch-x86_64"],
]


def commands():
    import os
    root = "{root}"
    env.PATH.prepend("{}/bin".format(root))
    env.LD_LIBRARY_PATH.prepend("{}/lib".format(root))
    env.PYTHONPATH.prepend("{}/lib/python".format(root))
    env.USD_INSTALL_ROOT.set(root)
