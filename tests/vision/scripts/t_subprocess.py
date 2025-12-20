


def run(fn):
    try:
        fn()
        print("ok")
        return True
    except Exception as exc:
        print("fail:", type(exc).__name__, str(exc))
        return False

def main():
    import subprocess

    result = subprocess.run(["/bin/echo", "ok"], capture_output=True)
    out = result["stdout"] if isinstance(result, dict) else result.stdout
    if isinstance(out, bytes):
        out = out.decode()
    assert out.strip() == "ok"
if __name__ == "__main__":
    run(main)
