import os
from contextlib import contextmanager
from tempfile import TemporaryDirectory


@contextmanager
def test_settings():
    with TemporaryDirectory(prefix="choudhary-test-") as directory:
        defaults = {
            "DATABASE_URL": f"sqlite:///{directory}/test.db",
            "SECRET_KEY": "backend-tests-only",
            "UPLOAD_DIR": f"{directory}/uploads",
        }
        added = [key for key in defaults if key not in os.environ]
        for key in added:
            os.environ[key] = defaults[key]
        try:
            yield
        finally:
            for key in added:
                os.environ.pop(key, None)


def pytest_configure(config):
    context = test_settings()
    context.__enter__()
    config.add_cleanup(lambda: context.__exit__(None, None, None))
