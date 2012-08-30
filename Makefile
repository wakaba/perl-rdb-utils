all: 

## ------ Setup ------

WGET = wget
GIT = git
PERL = perl
PERL_VERSION = latest
PERL_PATH = $(abspath local/perlbrew/perls/perl-$(PERL_VERSION)/bin)

PMB_PMTAR_REPO_URL =
PMB_PMPP_REPO_URL = 

Makefile-setupenv: Makefile.setupenv
	$(MAKE) --makefile Makefile.setupenv setupenv-update \
	    SETUPENV_MIN_REVISION=20120337

Makefile.setupenv:
	$(WGET) -O $@ https://raw.github.com/wakaba/perl-setupenv/master/Makefile.setupenv

lperl lprove local-perl perl-version perl-exec \
pmb-install pmb-update cinnamon \
local-submodules generatepm: %: Makefile-setupenv
	$(MAKE) --makefile Makefile.setupenv $@ \
	    PMB_PMTAR_REPO_URL=$(PMB_PMTAR_REPO_URL) \
	    PMB_PMPP_REPO_URL=$(PMB_PMPP_REPO_URL)

git-submodules:
	$(GIT) submodule update --init

deps: git-submodules pmb-install

## ------ Tests ------

PROVE = prove
PERL_ENV = PATH="bin/perl-$(PERL_VERSION)/pm/bin:$(PERL_PATH):$(PATH)" PERL5LIB="$(shell cat config/perl/libs.txt)"

test: test-deps test-main

test-deps: local-submodules deps

test-main:
	$(PERL_ENV) $(PROVE) t/*.t

## ------ Packaging ------

dist: always
	mkdir -p dist
	generate-pm-package config/dist/dbix-showsql.pi dist
	generate-pm-package config/dist/test-mysql-createdatabase.pi dist
	generate-pm-package config/dist/anyevent-dbi-hashref.pi dist
