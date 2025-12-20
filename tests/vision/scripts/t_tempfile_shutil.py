


def run(fn):
    try:
        fn()
        print("ok")
        return True
    except Exception as exc:
        print("fail:", type(exc).__name__, str(exc))
        return False

def main():
    import os
    import shutil
    import tempfile

    temp_dir = tempfile.mkdtemp(prefix="vision-")
    path = os.path.join(temp_dir, "a.txt")
    with open(path, "w") as handle:
        handle.write("ok")
    assert os.path.exists(path)
    shutil.rmtree(temp_dir)
if __name__ == "__main__":
    run(main)
