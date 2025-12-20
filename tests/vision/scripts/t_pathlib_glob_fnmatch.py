


def run(fn):
    try:
        fn()
        print("ok")
        return True
    except Exception as exc:
        print("fail:", type(exc).__name__, str(exc))
        return False

def main():
    import fnmatch
    import glob
    import pathlib

    assert fnmatch.fnmatch("foo.txt", "*.txt")
    p = pathlib.Path(".")
    assert p.exists()
    files = glob.glob("*")
    assert isinstance(files, list)
if __name__ == "__main__":
    run(main)
