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
use POSIX qw(strftime);

sub usage {
    print "Usage: ykksm-gen-keys.pl [--verbose] [--help]\n";
    print "                         [--urandom] [--progflags PROGFLAGS] START [END]\n";
    print "\n";
    print "  Tool to generate keys on the YKKSM-KEYPROV format.\n";
    print "\n";
    print "  START: Decimal start point.\n";
    print "\n";
    print "  END:   Decimal end point, if absent START is used as END.\n";
    print "\n";
    print "  --urandom:   Use /dev/urandom instead of /dev/random as entropy source.\n";
    print "\n";
    print "  --progflags PROGFLAGS: Add a final personalization configuration string.\n";
    print "\n";
    print "Usage example:\n";
    print "\n";
    print "  ./ykksm-gen-keys.pl --urandom 1 10 |\n";
    print "     gpg -a --sign --encrypt -r 1D2F473E > keys.txt\n";
    print "\n";
    exit 1;
}

if ($#ARGV==-1) {
    usage();
}

my $verbose = 0;
my $device = "/dev/random";
my $progflags;
while ($ARGV[0] =~ m/^-(.*)/) {
    my $cmd = shift @ARGV;
    if (($cmd eq "-v") || ($cmd eq "--verbose")) {
	$verbose = 1;
    } elsif (($cmd eq "-h") || ($cmd eq "--help")) {
	usage();
    } elsif ($cmd eq "--urandom") {
	$device = "/dev/urandom";
    } elsif ($cmd eq "--progflags") {
	$progflags = "," . shift;
    }
}

sub hex2modhex {
    my $_ = shift;
    tr/0123456789abcdef/cbdefghijklnrtuv/;
    return $_;
}

sub gethexrand {
    my $cnt = shift;
    my $buf;

    open (FH, $device) or die "Cannot open $device for reading";
    read (FH, $buf, $cnt) or die "Cannot read from $device";
    close FH;

    return lc(unpack("H*", $buf));
}

# main

my $now = strftime "%Y-%m-%dT%H:%M:%S", localtime;

my $start = shift @ARGV;
my $end = shift @ARGV || $start;
my $ctr;

print "# ykksm 1\n";
print "# start $start end $end device $device\n" if ($verbose);
print "# serialnr,identity,internaluid,aeskey,lockpw,created,accessed[,progflags]\n";

$ctr = $start;
while ($ctr <= $end) {
    my $hexctr = sprintf "%012x", $ctr;
    my $modhexctr = hex2modhex($hexctr);
    my $internaluid = gethexrand(6);
    my $aeskey = gethexrand(16);
    my $lockpw = gethexrand(6);
    print "# hexctr $hexctr modhexctr $modhexctr\n" if ($verbose);
    printf "$ctr,$modhexctr,$internaluid,$aeskey,$lockpw,$now,$progflags\n";
    $ctr++;
}

exit 0;
