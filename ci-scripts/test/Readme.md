# Unit and Integration Test Readme

## Moving to shunit2

The shunit2 framework provides several advantages to help with developing tests:
* Junit-style assert statements
* Mocking capabilities
* Standardized test output

In our environment, the goal is to use shunit2 for both unit and integration tests.
In the case of unit tests, the mocking capabilities allow you to test different branches of
the logic in shell script functions by controlling the return values from networking calls, etc.
For integration tests, shunit provides junit assertions and standardized test output.

## How to enable shunit for your test

1) Add shunit to the BOTTOM of your test

For unit tests:

```
# load shunit
. ${SHUNIT_PATH}
```

For integration tests:

```
# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
```

2) Make sure your test does not `exit 0` for a success.  This will cause vague errors in the
shunit2 code.  Instead, use an assert like: `assertEquals 0 0` indicating the test was a success.
Ideally, `exit 1` cases can be replaced with an appropriate assert statement.

3) Encapsulate your test code within a method starting with `test`.  For example:

```
testMyTest() {
  # test code goes here
}
```

3) shunit2 has a number of lifecycle methods you can use for your test.  See the documentation for
how to use `setUp()` `oneTimeSetUp()` `oneTimeTearDown()`, etc


### Resources

https://github.com/kward/shunit2

https://github.com/kward/shunit2#asserts

https://github.com/kward/shunit2/wiki/Cookbook
