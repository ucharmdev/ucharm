


def run(fn):
    try:
        fn()
        print("ok")
        return True
    except Exception as exc:
        print("fail:", type(exc).__name__, str(exc))
        return False

def main():
    import logging

    logger = logging.getLogger("demo")
    logger.setLevel(logging.INFO)
    logger.info("hello")
if __name__ == "__main__":
    run(main)
