name = "openusd"
version = "26.11.1"
description = "OpenUSD runtime and tools built in CI"

requires = [
    "python-3.10.14",
]

variants = [
    ["platform-linux", "arch-x86_64", "os-alma9"],
    ["platform-linux", "arch-x86_64", "os-rocky-9.8"],
]

def commands():
    env.PATH.prepend("{root}/bin")
    env.LD_LIBRARY_PATH.prepend("{root}/lib")
    env.PYTHONPATH.prepend("{root}/lib/python")
    env.USD_INSTALL_ROOT.set("{root}")
