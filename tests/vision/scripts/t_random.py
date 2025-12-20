


def run(fn):
    try:
        fn()
        print("ok")
        return True
    except Exception as exc:
        print("fail:", type(exc).__name__, str(exc))
        return False

def main():
    import random

    random.seed(1)
    val = random.randint(1, 10)
    assert 1 <= val <= 10
if __name__ == "__main__":
    run(main)
