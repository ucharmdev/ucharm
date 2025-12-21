def run(fn):
    try:
        fn()
        print("ok")
        return True
    except Exception as exc:
        print("fail:", type(exc).__name__, str(exc))
        return False


def main():
    import template

    src = "Hello {{name}}!"
    out = template.render(src, {"name": "world"})
    assert out == "Hello world!"

    assert template.render("{{user.name}}", {"user": {"name": "bob"}}) == "bob"

    src = "{% if ok %}yes{% else %}no{% end %}"
    assert template.render(src, {"ok": True}) == "yes"
    assert template.render(src, {"ok": False}) == "no"

    src = "{% for x in xs %}{{x}} {% end %}"
    assert template.render(src, {"xs": [1, 2, 3]}).strip() == "1 2 3"

    src = "{% for post in posts %}{{post.title}};{% end %}"
    out = template.render(src, {"posts": [{"title": "a"}, {"title": "b"}]})
    assert out == "a;b;"


if __name__ == "__main__":
    run(main)
