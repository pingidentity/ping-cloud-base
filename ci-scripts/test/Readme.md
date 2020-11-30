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
1\. Make sure your test script filename starts with a 2 digit (or greater) number and ends with .sh

For example, `02-password-log-test.sh` 

2\. Add shunit to the BOTTOM of your test

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

3\. Make sure your test does NOT `exit 0` for a success.  This will cause vague errors in the
shunit2 code.  Instead, use an assert like: `assertEquals 0 0` indicating the test was a success.
Tests that used to `exit 1` when an error occurred should be replaced with an appropriate assert statement.

4\. Encapsulate your test code within a method prefixed with `test`.  For example:

```
testMyTest() {
  # test code goes here
}
```

5\. shunit2 has a number of lifecycle methods you can use for your test.  See the documentation for
how to use `setUp()` `oneTimeSetUp()` `oneTimeTearDown()`, etc


## Guidelines for writing a good test

When writing a test, keep in mind that you will not probably be the one trying to figure out
what went wrong if your test fails.  Think through the information someone will need to quickly figure 
out what went wrong.

1\. Test naming - Give your test a descriptive, accurate name.  It's ok if the name is long.  The
 name will be the first clue someone has to figure out the intent.  Refactor the name if the context 
 of the test changes.

2\. Do not use `set -x` debugging - Shell debugging is very noisy in the logs and it often 
 cascades into the shunit test infrastructure code itself (yielding very confusing messages).  Please 
 rely on shunit assert statements instead (see next item).

3\. Use shunit assert statements to verify each step in the test - Test assert statements are incredibly 
helpful for a few reasons:

  a) When used with a proper message, assert statements are quiet.  They only output when there's 
    a real issue.  This means you don't have to rely on noisy `echo` debug statements to trace what went 
    wrong in the code.
  
  b) They communicate the intended state of the test at the point where they're executed. 
  
  c) The error message can be injected with context to help someone figure out the issue.  For example,
  
```
  create_shared_secret_response=$(create_shared_secret "${PA_ADMIN_PASSWORD}" "${PINGACCESS_API}" "${agent_shared_secret}")
  
  # The assert will print the inputs for the previous call.  This is helpful when one or more of the input values
  # is blank or unexpected.
  assertEquals "Failed to create a shared secret with POST request to: ${PINGACCESS_API} using admin password: ${PA_ADMIN_PASSWORD} returned: ${create_shared_secret_response}" 0 $?

  shared_secret_id=$(parse_value_from_response "${create_shared_secret_response}" 'id')
  
  # Here too, printing the input to the parse function may quickly reveal the issue.
  assertEquals "Failed to parse the id from the shared secret response: ${create_shared_secret_response}" 0 $?
```

### Resources

https://github.com/kward/shunit2

https://github.com/kward/shunit2#asserts

https://github.com/kward/shunit2/wiki/Cookbook
