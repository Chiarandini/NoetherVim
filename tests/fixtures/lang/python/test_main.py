from main import add


def test_passes():
    assert add(1, 2) == 3


def test_fails():
    assert add(1, 2) == 4
