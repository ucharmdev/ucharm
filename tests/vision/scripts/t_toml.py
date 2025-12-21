def run(fn):
    try:
        fn()
        print("ok")
        return True
    except Exception as exc:
        print("fail:", type(exc).__name__, str(exc))
        return False


def main():
    import os

    import toml
    import tomllib

    doc = """a = 1
name = "ucharm"
[db]
path = "./test.db"
nums = [1, 2, 3]
"""
    d = toml.loads(doc)
    assert d["a"] == 1
    assert d["name"] == "ucharm"
    assert d["db"]["path"] == "./test.db"
    assert d["db"]["nums"] == [1, 2, 3]

    dumped = toml.dumps({"a": 1, "db": {"path": "./x.db"}})
    assert "a = 1" in dumped
    assert "[db]" in dumped
    assert 'path = "./x.db"' in dumped

    path = "__ucharm_toml_test.toml"
    try:
        with open(path, "w") as f:
            f.write(doc)
        assert toml.load(path)["db"]["path"] == "./test.db"
        assert tomllib.load(path)["db"]["path"] == "./test.db"
    except Exception:
        os.remove(path)
        raise

    os.remove(path)


if __name__ == "__main__":
    run(main)
