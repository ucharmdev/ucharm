


def run(fn):
    try:
        fn()
        print("ok")
        return True
    except Exception as exc:
        print("fail:", type(exc).__name__, str(exc))
        return False

def main():
    import re

    m = re.match(r"(a+)(b+)", "aaabbb")
    assert m is not None
    assert m.group(2) == "bbb"
if __name__ == "__main__":
    run(main)
