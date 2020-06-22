#!/bin/bash

# Run this simple test
# to make sure shunit2
# exists and is
# accessible.
testShunit2IsAccessible() {
  assertEquals 1 1
}

# load shunit
. ${SHUNIT_PATH}
