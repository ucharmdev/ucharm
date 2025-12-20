


def run(fn):
    try:
        fn()
        print("ok")
        return True
    except Exception as exc:
        print("fail:", type(exc).__name__, str(exc))
        return False

def main():
    import datetime

    dt = datetime.datetime(2020, 1, 2, 3, 4, 5)
    assert dt.year == 2020
    assert dt.strftime("%Y-%m-%d") == "2020-01-02"
if __name__ == "__main__":
    run(main)
