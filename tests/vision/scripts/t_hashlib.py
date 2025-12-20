


def run(fn):
    try:
        fn()
        print("ok")
        return True
    except Exception as exc:
        print("fail:", type(exc).__name__, str(exc))
        return False

def main():
    import hashlib

    h = hashlib.sha256(b"hello").hexdigest()
    assert len(h) == 64
if __name__ == "__main__":
    run(main)
