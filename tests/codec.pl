#!/usr/bin/perl

use strict;
use warnings;

# Coder/Decoder test. Uses actual data.

use lib '../lib';
use Net::OnlineCode::Encoder;
use Net::OnlineCode::Decoder;
use Net::OnlineCode::RNG;

# export xor helper function names into our namespace
use Net::OnlineCode ':xor';

print "Testing: ENCODER AND DECODER\n";

my $blksiz = shift @ARGV || 4;
my $seed   = shift @ARGV;

# test string is 41 characters (a prime, so it needs padding unless
# blocksize is 1 or 41)
my $test = "The quick brown fox jumps over a lazy dog";


# First thing to do is set up RNGs.
my $erng;
if (defined($seed)) {
  die "supplied seed must be a hex number (40 characters for SHA1 RNG\n"
    unless length($seed) == 40 and ($seed =~ m/^[0-9a-f]+$/i);

  $erng = Net::OnlineCode::RNG->new(pack "H*", $seed);

} else {

 $erng = Net::OnlineCode::RNG->new_random;

}

my $drng = Net::OnlineCode::RNG->new;
$drng->seed($erng->get_seed);

die "initial seed mismatch\n" unless $erng->get_seed eq $drng->get_seed;
die "initial rng mismatch\n"  unless $erng->as_hex eq $drng->as_hex;

print "SEED: " . $erng->as_hex . "\n";

print "Test string: $test\n";

print "Length: " . length($test) . "\n";
print "Block size: $blksiz\n";

# Common Setup

my $istring  = $test;
my $msg_size = length($test);
my $ostring  = "";

# pad input string up to a multiple of blksiz in length
my $padding = ($blksiz - $msg_size) % $blksiz;
print "Padding length: $padding\n";
$istring .= "x" x $padding;

my $mblocks = length($istring) / $blksiz;

print "Padded string: $istring\n";
print "Message blocks: $mblocks\n";

# Set up encoder, decoder

my $enc = Net::OnlineCode::Encoder
  ->new(mblocks => $mblocks, initial_rng => $erng, expand_aux => 1);

die "Failed to create encoder. Quitting\n" unless ref($enc);

# extract parameters from encoder
my $e = $enc->get_e;
my $q = $enc->get_q;
my $f = $enc->get_f;
my $coblocks = $enc->get_coblocks;

print "Encoder parameters:\ne= $e, q = $q, f=$f\n";
print "Expected number of check blocks: " .
  int (0.5 + ($mblocks * (1 + $e * $q))) .  "\n";
print "Failure probability: " . (($e/2)**($q + 1)) . "\n";

print "Setting up decoder with e=$e, q=$q, mblocks=$mblocks\n";

# set up decoder with same parameters
my $dec = Net::OnlineCode::Decoder
  ->new(mblocks => $mblocks, initial_rng => $drng,
	e => $e, q=> $q, expand_aux => 1);
die "Failed to create decoder. Quitting\n" unless ref($dec);

# substr won't allow us to write to portions outside the string, so
# zero it out
$ostring = "x" x (1 * length($istring));

print "Entering main loop\n";

# main loop
my @check_blocks = ();
my $check_count = 0;
my $done = 0;
until ($done) {

  # normally, we'd call seed_random, but for testing we want a
  # deterministic order
  my $block_id     = $erng->seed($erng->as_string);

  die "encoder random seed != block_id\n" unless $block_id eq $erng->get_seed;

  ++$check_count;
  print "\nENCODE Block #$check_count " . $erng->as_hex . "\n";

  my $enc_xor_list = $enc->create_check_block($erng);

  print "Encoder check block: " . (join ", ", @$enc_xor_list) . "\n";


  # xor check block
  my $contents = substr($istring,  $blksiz * shift @$enc_xor_list, $blksiz);
  foreach (@$enc_xor_list) {
    xor_strings(\$contents,
		substr($istring,  $blksiz * $_, $blksiz));
  }

  # synchronise decoder rng with same seed as encoder
  $drng->seed($block_id);
  print "\nDECODE Block #$check_count " . $drng->as_hex . "\n";


  # save contents of checkblock
  push @check_blocks, $contents;

  my @decoded;
  ($done,@decoded)  = $dec->accept_check_block($drng);

  # right now I don't have a way to check that the check block was
  # composed the same was as in the decoder. That information is
  # stored in the decoder's graph object, though.

  print "This checkblock solved " . scalar(@decoded) . " message block(s)\n";
  print "This solves the entire message\n" if $done;

  foreach my $decoded_block (@decoded) {

    my @dec_xor_list = $dec->xor_list($decoded_block);

    print "Decoded message block $decoded_block is composed of: ",
      (join ", ", @dec_xor_list) . "\n";

    my ($block, $i);
    $i = shift @dec_xor_list;
    if ($i >= $mblocks) {
      $block = $check_blocks[$i - $coblocks];
    } else {
      $block = substr($ostring,  $blksiz * $i, $blksiz);
    }
    foreach my $xor_block (@dec_xor_list) {
      if ($xor_block >= $coblocks) {
	xor_strings(\$block, $check_blocks[$xor_block - $coblocks]);
      } else {
	xor_strings(\$block,
		substr($ostring,  $blksiz * $xor_block, $blksiz));
      }
    }
    print "Decoded message block: '$block'\n";

    substr($ostring, $decoded_block * $blksiz, $blksiz) = $block;
  }
}


print "Decoded text: '$ostring'\n";

