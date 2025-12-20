


def run(fn):
    try:
        fn()
        print("ok")
        return True
    except Exception as exc:
        print("fail:", type(exc).__name__, str(exc))
        return False

def main():
    import textwrap

    text = "one two three four"
    wrapped = textwrap.fill(text, width=6)
    assert "\n" in wrapped
if __name__ == "__main__":
    run(main)
