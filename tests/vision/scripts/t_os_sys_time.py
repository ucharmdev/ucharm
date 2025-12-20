


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
    import sys
    import time

    assert isinstance(sys.argv, list)
    assert os.getcwd()
    t = time.time()
    assert t > 0
if __name__ == "__main__":
    run(main)
