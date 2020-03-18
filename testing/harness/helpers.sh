alias autolandctl="${TESTDIR}/testing/harness/autolandctl.py"

setup_test_env() {
    ${TESTDIR}/run-tests --restart --no-timing
    hg clone ${HGWEB_URL}/first-repo first-client > /dev/null
    hg clone ${HGWEB_URL}/second-repo second-client > /dev/null
    hg clone ${HGWEB_URL}/third-repo third-client > /dev/null
}
