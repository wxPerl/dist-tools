# Copyright (C) 2002-2003 Rob Brown (bbb@cpan.org)
# Chicken-And-Egg rpm SPEC file generator.

use strict;

my @cmd = (
    "./cpan2rpm",
    ((eval("use File::Temp"),$@) ? ("--tempdir","/tmp/cpan2rpm") : ()),
    "--force",
    "--spec-only",
    "--spec", "./cpan2rpm.spec",
    "--requires", q{ %([ `rpm -q rpm --qf %%{version}|awk -F . '{print $1}'` -gt 3 ] && echo rpm-build || echo rpm)},
    "--no-prfx",
    "--buildarch=noarch",
    "--doc", "perl.req.patch",
    "."
    );

exec(@cmd) or die "exec failure: $!";
