name = "python"
version = "3.10.14"
description = "Python runtime for OpenUSD CI builds"

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

    stop("Unsupported OS variant for python package: {}".format(sorted(variant_tokens)))


def commands():
    variant_root = _variant_root()
    env.PATH.prepend("{}/bin".format(variant_root))
    env.LD_LIBRARY_PATH.prepend("{}/lib".format(variant_root))
    env.PYTHONHOME.set(variant_root)
