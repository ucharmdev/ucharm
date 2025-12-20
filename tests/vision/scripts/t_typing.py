


def run(fn):
    try:
        fn()
        print("ok")
        return True
    except Exception as exc:
        print("fail:", type(exc).__name__, str(exc))
        return False

def main():
    import typing

    assert hasattr(typing, "List") or hasattr(typing, "list")
if __name__ == "__main__":
    run(main)
