alias autolandctl="${TESTDIR}/testing/harness/autolandctl.py"

setup_test_env() {
    ${TESTDIR}/run-tests --restart --no-timing
    hg clone ${HGWEB_URL}/test-repo client > /dev/null
}
