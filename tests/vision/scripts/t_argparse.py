


def run(fn):
    try:
        fn()
        print("ok")
        return True
    except Exception as exc:
        print("fail:", type(exc).__name__, str(exc))
        return False

def main():
    import argparse

    parser = argparse.ArgumentParser(prog="demo")
    parser.add_argument("--count", type=int, default=2)
    parser.add_argument("name")
    args = parser.parse_args(["--count", "3", "alice"])
    assert args.count == 3
    assert args.name == "alice"
if __name__ == "__main__":
    run(main)
