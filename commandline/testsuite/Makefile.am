#
# Makefile.am for .../testsuite
#

AUTOMAKE_OPTIONS = dejagnu
EXTRA_DIST = $(wildcard tests/*.out) $(wildcard tests/*.err) $(wildcard tests/*.ycp) $(wildcard tests/*.yh) tests/include/testsuitedata.ycp

testsuite_prepare = @ydatadir@/testsuite/Makefile.testsuite

all-local: $(testsuite_prepare)
	make -f $(testsuite_prepare) RPMNAME=$(RPMNAME) srcdir=$(srcdir)

clean-local: $(testsuite_prepare)
	make -f $(testsuite_prepare) RPMNAME=$(RPMNAME) srcdir=$(srcdir) clean

check-local: $(testsuite_prepare)
	make -f $(testsuite_prepare) RPMNAME=$(RPMNAME) srcdir=$(srcdir) check

# EOF
