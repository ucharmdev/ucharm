import sys


def run(fn):
    try:
        fn()
        print("ok")
        return True
    except Exception as exc:
        print("fail:", type(exc).__name__, str(exc))
        return False


if __name__ == "__main__":
    sys.stdout.write("fail: util invoked directly\\n")
