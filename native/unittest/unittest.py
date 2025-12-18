"""
unittest - Unit testing framework

This is a MicroPython-compatible implementation of Python's unittest module.
It provides the TestCase class and basic test running functionality.

Note: This implementation provides a subset of CPython's unittest functionality,
focused on the most commonly used features.
"""

import sys

__all__ = [
    "TestCase",
    "TestSuite",
    "TestResult",
    "TextTestRunner",
    "main",
    "skip",
    "skipIf",
    "skipUnless",
    "expectedFailure",
]


class SkipTest(Exception):
    """Exception raised to skip a test."""

    pass


class _ExpectedFailure(Exception):
    """Exception raised when a test is expected to fail."""

    pass


class _SkipWrapper:
    """Wrapper for skipped tests."""

    def __init__(self, func, reason):
        self._func = func
        self._skip_reason = reason
        try:
            self.__name__ = func.__name__
        except AttributeError:
            self.__name__ = "unknown"

    def __call__(self, *args, **kwargs):
        raise SkipTest(self._skip_reason)

    def __get__(self, obj, objtype=None):
        """Support instance method binding."""
        if obj is None:
            return self
        # Return a bound version that still has our attributes
        bound = _BoundSkipWrapper(self, obj)
        return bound


class _BoundSkipWrapper:
    """Bound version of skip wrapper."""

    def __init__(self, wrapper, instance):
        self._wrapper = wrapper
        self._instance = instance
        self._skip_reason = wrapper._skip_reason
        try:
            self.__name__ = wrapper.__name__
        except AttributeError:
            self.__name__ = "unknown"

    def __call__(self, *args, **kwargs):
        raise SkipTest(self._skip_reason)


class _ExpectedFailureWrapper:
    """Wrapper for expected failure tests."""

    def __init__(self, func):
        self._func = func
        self._expected_failure = True
        try:
            self.__name__ = func.__name__
        except AttributeError:
            self.__name__ = "unknown"

    def __call__(self, *args, **kwargs):
        return self._func(*args, **kwargs)

    def __get__(self, obj, objtype=None):
        """Support instance method binding."""
        if obj is None:
            return self
        # Return a bound version that still has our attributes
        bound = _BoundExpectedFailureWrapper(self, obj)
        return bound


class _BoundExpectedFailureWrapper:
    """Bound version of expected failure wrapper."""

    def __init__(self, wrapper, instance):
        self._wrapper = wrapper
        self._instance = instance
        self._func = wrapper._func
        self._expected_failure = True
        try:
            self.__name__ = wrapper.__name__
        except AttributeError:
            self.__name__ = "unknown"

    def __call__(self, *args, **kwargs):
        return self._func(self._instance, *args, **kwargs)


def skip(reason):
    """Decorator to unconditionally skip a test."""

    def decorator(func):
        return _SkipWrapper(func, reason)

    return decorator


def skipIf(condition, reason):
    """Decorator to skip a test if condition is true."""
    if condition:
        return skip(reason)
    return lambda func: func


def skipUnless(condition, reason):
    """Decorator to skip a test unless condition is true."""
    if not condition:
        return skip(reason)
    return lambda func: func


def expectedFailure(func):
    """Decorator to mark a test as expected to fail."""
    return _ExpectedFailureWrapper(func)


class TestResult:
    """Holder for test result information."""

    def __init__(self):
        self.failures = []
        self.errors = []
        self.skipped = []
        self.expectedFailures = []
        self.unexpectedSuccesses = []
        self.testsRun = 0
        self.shouldStop = False

    def startTest(self, test):
        self.testsRun += 1

    def stopTest(self, test):
        pass

    def addSuccess(self, test):
        pass

    def addError(self, test, err):
        self.errors.append((test, err))

    def addFailure(self, test, err):
        self.failures.append((test, err))

    def addSkip(self, test, reason):
        self.skipped.append((test, reason))

    def addExpectedFailure(self, test, err):
        self.expectedFailures.append((test, err))

    def addUnexpectedSuccess(self, test):
        self.unexpectedSuccesses.append(test)

    def wasSuccessful(self):
        return len(self.failures) == 0 and len(self.errors) == 0

    def __repr__(self):
        return f"<TestResult run={self.testsRun} failures={len(self.failures)} errors={len(self.errors)}>"


class TestCase:
    """A class whose instances are single test cases."""

    def __init__(self, methodName="runTest"):
        self._testMethodName = methodName
        self._outcome = None

    def __str__(self):
        return f"{self.__class__.__name__}.{self._testMethodName}"

    def __repr__(self):
        return f"<{self.__class__.__name__} testMethod={self._testMethodName}>"

    def setUp(self):
        """Hook method for setting up the test fixture before exercising it."""
        pass

    def tearDown(self):
        """Hook method for deconstructing the test fixture after testing it."""
        pass

    @classmethod
    def setUpClass(cls):
        """Hook method for setting up class fixture before running tests in the class."""
        pass

    @classmethod
    def tearDownClass(cls):
        """Hook method for deconstructing the class fixture after running all tests in the class."""
        pass

    def run(self, result=None):
        if result is None:
            result = TestResult()

        result.startTest(self)

        testMethod = getattr(self, self._testMethodName)

        # Check for skip decorators
        skip_reason = getattr(testMethod, "_skip_reason", None)
        if skip_reason is not None:
            result.addSkip(self, skip_reason)
            result.stopTest(self)
            return result

        expected_failure = getattr(testMethod, "_expected_failure", False)

        try:
            self.setUp()
        except SkipTest as e:
            result.addSkip(self, str(e))
            result.stopTest(self)
            return result
        except Exception as e:
            result.addError(self, e)
            result.stopTest(self)
            return result

        try:
            testMethod()
            if expected_failure:
                result.addUnexpectedSuccess(self)
            else:
                result.addSuccess(self)
        except SkipTest as e:
            result.addSkip(self, str(e))
        except AssertionError as e:
            if expected_failure:
                result.addExpectedFailure(self, e)
            else:
                result.addFailure(self, e)
        except Exception as e:
            if expected_failure:
                result.addExpectedFailure(self, e)
            else:
                result.addError(self, e)

        try:
            self.tearDown()
        except Exception as e:
            result.addError(self, e)

        result.stopTest(self)
        return result

    def skipTest(self, reason):
        """Skip this test."""
        raise SkipTest(reason)

    # =========================================================================
    # Assert methods
    # =========================================================================

    def fail(self, msg=None):
        """Fail immediately, with the given message."""
        raise AssertionError(msg or "Test failed")

    def assertTrue(self, expr, msg=None):
        """Check that the expression is true."""
        if not expr:
            raise AssertionError(msg or f"Expected True, got {expr!r}")

    def assertFalse(self, expr, msg=None):
        """Check that the expression is false."""
        if expr:
            raise AssertionError(msg or f"Expected False, got {expr!r}")

    def assertEqual(self, first, second, msg=None):
        """Check that first and second are equal."""
        if first != second:
            raise AssertionError(msg or f"{first!r} != {second!r}")

    def assertNotEqual(self, first, second, msg=None):
        """Check that first and second are not equal."""
        if first == second:
            raise AssertionError(msg or f"{first!r} == {second!r}")

    def assertIs(self, first, second, msg=None):
        """Check that first and second are the same object."""
        if first is not second:
            raise AssertionError(msg or f"{first!r} is not {second!r}")

    def assertIsNot(self, first, second, msg=None):
        """Check that first and second are not the same object."""
        if first is second:
            raise AssertionError(msg or f"{first!r} is {second!r}")

    def assertIsNone(self, obj, msg=None):
        """Check that obj is None."""
        if obj is not None:
            raise AssertionError(msg or f"{obj!r} is not None")

    def assertIsNotNone(self, obj, msg=None):
        """Check that obj is not None."""
        if obj is None:
            raise AssertionError(msg or "Object is None")

    def assertIn(self, member, container, msg=None):
        """Check that member is in container."""
        if member not in container:
            raise AssertionError(msg or f"{member!r} not in {container!r}")

    def assertNotIn(self, member, container, msg=None):
        """Check that member is not in container."""
        if member in container:
            raise AssertionError(msg or f"{member!r} in {container!r}")

    def assertIsInstance(self, obj, cls, msg=None):
        """Check that obj is an instance of cls."""
        if not isinstance(obj, cls):
            raise AssertionError(msg or f"{obj!r} is not an instance of {cls}")

    def assertNotIsInstance(self, obj, cls, msg=None):
        """Check that obj is not an instance of cls."""
        if isinstance(obj, cls):
            raise AssertionError(msg or f"{obj!r} is an instance of {cls}")

    def assertGreater(self, first, second, msg=None):
        """Check that first > second."""
        if not first > second:
            raise AssertionError(msg or f"{first!r} is not greater than {second!r}")

    def assertGreaterEqual(self, first, second, msg=None):
        """Check that first >= second."""
        if not first >= second:
            raise AssertionError(
                msg or f"{first!r} is not greater than or equal to {second!r}"
            )

    def assertLess(self, first, second, msg=None):
        """Check that first < second."""
        if not first < second:
            raise AssertionError(msg or f"{first!r} is not less than {second!r}")

    def assertLessEqual(self, first, second, msg=None):
        """Check that first <= second."""
        if not first <= second:
            raise AssertionError(
                msg or f"{first!r} is not less than or equal to {second!r}"
            )

    def assertAlmostEqual(self, first, second, places=7, msg=None, delta=None):
        """Check that first and second are approximately equal."""
        if delta is not None:
            if abs(first - second) > delta:
                raise AssertionError(
                    msg or f"{first!r} and {second!r} differ by more than {delta}"
                )
        else:
            if round(abs(first - second), places) != 0:
                raise AssertionError(
                    msg or f"{first!r} and {second!r} differ at place {places}"
                )

    def assertNotAlmostEqual(self, first, second, places=7, msg=None, delta=None):
        """Check that first and second are not approximately equal."""
        if delta is not None:
            if abs(first - second) <= delta:
                raise AssertionError(
                    msg or f"{first!r} and {second!r} are within {delta}"
                )
        else:
            if round(abs(first - second), places) == 0:
                raise AssertionError(
                    msg or f"{first!r} and {second!r} are equal to {places} places"
                )

    def assertRaises(self, exception, *args, **kwargs):
        """Check that an exception is raised."""
        if args:
            # Called with a callable
            callable_obj = args[0]
            args = args[1:]
            try:
                callable_obj(*args, **kwargs)
            except exception:
                return
            except Exception as e:
                raise AssertionError(
                    f"Expected {exception.__name__}, got {type(e).__name__}: {e}"
                )
            raise AssertionError(f"Expected {exception.__name__} to be raised")
        else:
            # Return a context manager
            return _AssertRaisesContext(exception, self)

    def assertRegex(self, text, regex, msg=None):
        """Check that the regex matches the text."""
        import re

        if not re.search(regex, text):
            raise AssertionError(msg or f"Regex {regex!r} did not match {text!r}")

    def assertNotRegex(self, text, regex, msg=None):
        """Check that the regex does not match the text."""
        import re

        if re.search(regex, text):
            raise AssertionError(msg or f"Regex {regex!r} matched {text!r}")


class _AssertRaisesContext:
    """Context manager for assertRaises."""

    def __init__(self, expected, test_case):
        self.expected = expected
        self.test_case = test_case
        self.exception = None

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if exc_type is None:
            raise AssertionError(f"Expected {self.expected.__name__} to be raised")
        if not issubclass(exc_type, self.expected):
            return False  # Re-raise the exception
        self.exception = exc_val
        return True


class TestSuite:
    """A collection of tests."""

    def __init__(self, tests=()):
        self._tests = list(tests)

    def __iter__(self):
        return iter(self._tests)

    def addTest(self, test):
        self._tests.append(test)

    def addTests(self, tests):
        for test in tests:
            self.addTest(test)

    def run(self, result):
        for test in self:
            if result.shouldStop:
                break
            test.run(result)
        return result

    def countTestCases(self):
        return sum(1 for _ in self)


class TestLoader:
    """Load tests from a module or class."""

    testMethodPrefix = "test"

    def loadTestsFromTestCase(self, testCaseClass):
        """Return a suite of all test cases contained in testCaseClass."""
        tests = []
        for name in dir(testCaseClass):
            if name.startswith(self.testMethodPrefix):
                tests.append(testCaseClass(name))
        return TestSuite(tests)

    def loadTestsFromModule(self, module):
        """Return a suite of all test cases contained in the given module."""
        tests = []
        for name in dir(module):
            obj = getattr(module, name)
            if (
                isinstance(obj, type)
                and issubclass(obj, TestCase)
                and obj is not TestCase
            ):
                tests.append(self.loadTestsFromTestCase(obj))
        return TestSuite(tests)


class TextTestRunner:
    """A test runner that displays results in textual form."""

    def __init__(self, stream=None, verbosity=1):
        self.stream = stream or sys.stdout
        self.verbosity = verbosity

    def run(self, test):
        result = TestResult()
        test.run(result)

        # Print results
        print(file=self.stream)

        # Print errors
        for test_case, err in result.errors:
            print(f"ERROR: {test_case}", file=self.stream)
            print(f"  {err}", file=self.stream)

        # Print failures
        for test_case, err in result.failures:
            print(f"FAIL: {test_case}", file=self.stream)
            print(f"  {err}", file=self.stream)

        # Print summary
        print("-" * 70, file=self.stream)
        print(f"Ran {result.testsRun} tests", file=self.stream)

        if result.wasSuccessful():
            print("OK", file=self.stream)
        else:
            print(
                f"FAILED (failures={len(result.failures)}, errors={len(result.errors)})",
                file=self.stream,
            )

        return result


def main(module="__main__", exit=True, verbosity=1):
    """Run tests from a module."""
    if isinstance(module, str):
        import sys

        module = sys.modules.get(module)
        if module is None:
            print(f"Module {module} not found")
            return

    loader = TestLoader()
    suite = loader.loadTestsFromModule(module)
    runner = TextTestRunner(verbosity=verbosity)
    result = runner.run(suite)

    if exit:
        sys.exit(0 if result.wasSuccessful() else 1)
    return result
