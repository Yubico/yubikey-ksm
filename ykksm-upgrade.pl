#!/usr/bin/perl

# Written by Simon Josefsson <simon@josefsson.org>.
# Copyright (c) 2009 Yubico AB
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#
#   * Redistributions in binary form must reproduce the above
#     copyright notice, this list of conditions and the following
#     disclaimer in the documentation and/or other materials provided
#     with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

use strict;
use DBI;
use POSIX qw(strftime);

sub usage {
    print "Usage: $0 [--help]\n";
    print "          [--database DBI] [--db-user USER] [--db-passwd PASSWD]\n";
    print "          [--creator CREATOR]\n";
    print "\n";
    print "Tool to upgrade data in database based on special format.\n";
    print "\n";
    print "  --database DBI: Database identifier, see http://dbi.perl.org/\n";
    print "                  defaults to a MySQL database ykksm on localhost,\n";
    print "                  i.e., DBI::mysql:ykksm.\n";
    print "\n";
    print "  --db-user USER: Database username to use, defaults to empty string.\n";
    print "\n";
    print "  --db-passwd PASSWD: Database password to use, defaults to empty string.\n";
    print "\n";
    print "  --creator CREATOR: Short string with creator info.\n";
    print "                     Defaults to using the PGP signer key id, normally.\n";
    print "                     you don't change this.\n";
    print "\n";
    print "Usage example:\n";
    print "\n";
    print "  $0 < keys.txt\n";
    print "\n";
    exit 1;
}

my $creator;
my $db = "dbi:mysql:ykksm";
my $dbuser;
my $dbpasswd;
while ($ARGV[0] =~ m/^-(.*)/) {
    my $cmd = shift @ARGV;
    if (($cmd eq "-h") || ($cmd eq "--help")) {
	usage();
    } elsif ($cmd eq "--creator") {
	$creator = shift;
    } elsif ($cmd eq "--database") {
	$db = shift;
    } elsif ($cmd eq "--db-user") {
	$dbuser = shift;
    } elsif ($cmd eq "--db-passwd") {
	$dbpasswd = shift;
    }
}

if ($#ARGV>=0) {
    usage();
}

my $infilename = "tmp.$$";
my $verify_status;
my $encrypted_to;
my $signed_by;

# Read input into temporary file.
open TMPFILE, ">$infilename"
    or die "Cannot open $infilename for writing";
while (<>) {
    print TMPFILE $_;
}
close TMPFILE;

END { unlink $infilename; }

# Get status
open(GPGV, "gpg --status-fd 1 --output /dev/null < $infilename 2>&1 |")
    or die "Cannot launch gpg";
while (<GPGV>) {
    $verify_status .= $_;
    $encrypted_to = $1 if m,^\[GNUPG:\] ENC_TO ([0-9A-F]+) ,;
    $signed_by = $1 if m,^\[GNUPG:\] VALIDSIG ([0-9A-F]+) ,;
}
close GPGV;

print "Verification output:\n" . $verify_status;
print "encrypted to: " . $encrypted_to . "\n";
print "signed by: " . $signed_by . "\n";

die "Input not signed?" if !$signed_by;

my $dbh = DBI->connect($db, $dbuser, $dbpasswd, {'RaiseError' => 1});
my $inserth = $dbh->prepare_cached(qq{
INSERT INTO yubikeys (creator, created, serialnr,
                      publicname, internalname, aeskey, lockcode)
VALUES (?, NOW(), 0, ?, ?, ?, '000000000000')
})
    or die "Couldn't prepare statement: " . $dbh->errstr;

$creator = $signed_by if !$creator;

open(GPGV, "gpg < $infilename 2>/dev/null |")
    or die "Cannot launch gpg";
while (<GPGV>) {
    next if m:^#:;
    my ($publicname, $aeskey, $internalname) =
	  m%^id ([cbdefghijklnrtuv]+) key ([0-9a-f]+) uid ([0-9a-f]+)%;
    print "line: $_";
    print "\tpublicname $publicname internalname $internalname aeskey $aeskey eol\n";

    my $rows_changed = $dbh->do(q{UPDATE yubikeys SET publicname = ? WHERE publicname = ?}, undef, ("old-" . $publicname, $publicname))
	or die "Cannot update database: " . $dbh->errstr;
    
    $inserth->execute($creator, $publicname, $internalname, $aeskey)
	or die "Database insert error: " . $dbh->errstr;
}

close GPGV;
$dbh->disconnect();

exit 0;
