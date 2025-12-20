


def run(fn):
    try:
        fn()
        print("ok")
        return True
    except Exception as exc:
        print("fail:", type(exc).__name__, str(exc))
        return False

def main():
    import signal

    called = {"hit": False}

    def handler(signum, frame):
        called["hit"] = True

    signal.signal(signal.SIGINT, handler)
    assert signal.getsignal(signal.SIGINT) is handler
if __name__ == "__main__":
    run(main)
