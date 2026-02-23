name = "openusd"
version = "25.05.1"
description = "OpenUSD runtime and tools built in CI"

requires = [
    "python-3.10.14",
]

variants = [
    ["platform-linux", "arch-x86_64", "os-alma9"],
    ["platform-linux", "arch-x86_64", "os-rocky9"],
]


def _variant_root():
    variant_tokens = set(str(token) for token in (this.variant or []))

    if "os-alma9" in variant_tokens:
        return "{root}/alma9"
    if "os-rocky9" in variant_tokens:
        return "{root}/rocky9"

    stop("Unsupported OS variant for openusd package: {}".format(sorted(variant_tokens)))


def commands():
    variant_root = _variant_root()
    env.PATH.prepend("{}/bin".format(variant_root))
    env.LD_LIBRARY_PATH.prepend("{}/lib".format(variant_root))
    env.PYTHONPATH.prepend("{}/lib/python".format(variant_root))
    env.USD_INSTALL_ROOT.set(variant_root)
