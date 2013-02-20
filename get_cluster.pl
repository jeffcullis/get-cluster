#!/usr/bin/perl -w

use strict;
use warnings;

use Getopt::Long;

my $inmask = ''; # Filename of the .nii mask
my @full_mask; # ijk array of entire mask
my @max; # Keeps track of the max value found in each col of the input mask.
my @min; # As above for min.
my $cbox = ''; # 'box radius' for 3dmaskdump.

my $outxyz = '';
my $xyz_fh;
my $outijk = '';
my $ijk_fh;
my $outnii = '';
my @onii; # Used to store coords for later 3dUndump to nii.

my @start_coords; # All starting coordinates.
my @coord_stack; # A stack of coordinates left to check for membership in a given cluster.

sub die_usage
{
	die "Usage: $0 --coord 73,47,59 44,36,108,2 -i <1D input mask> -o <1D output mask>."
}

# Parse command-line options and set up starting coordinate values.
sub parse_cmds
{
	my @raw_start_coords;
	GetOptions('coord|c=s{,}' => \@raw_start_coords,
		'inmask|i=s' => \$inmask,
		'outxyz=s' => \$outxyz,
		'outijk=s' => \$outijk,
		'outnii|o=s' => \$outnii,
		'cbox=i' => \$cbox
		);
	
	if( $outxyz ) {
		open($xyz_fh, '>', $outxyz) or die "Couldn't open file $outxyz\n";
	}
	if( $outijk ) {
		open($ijk_fh, '>', $outijk) or die "Couldn't open file $outijk\n";
	}
	unless( $outxyz or $outijk or $outnii ) {
		$outijk = "-";
		open($ijk_fh, '>-'); # Write 1D to STDOUT
	}
	
	$#raw_start_coords >= 0 || &die_usage;
	
	foreach my $sc (@raw_start_coords) {
		my @tmp = split(",", $sc);
		$#tmp == 2 || $#tmp == 3 || &die_usage;
		push(@tmp,1) if $#tmp == 2;
		push @start_coords, [ @tmp ];
	}
}	

# Read in the entire mask in $inmask (including zeros) to the array @full_mask
sub read_mask
{
	my $boxcmd = "";
	# use the -cbox param to dump a subregion, so long as only one 
	# coordinate is specified.
	if( $cbox =~ /^[0-9]+$/ && $#start_coords == 0 ) {
		my @sc = @{$start_coords[0]};
		$boxcmd = "-ibox ";
		for my $i (0 .. 2) { 
			$boxcmd .= ($sc[$i]-$cbox) . ":" . ( $sc[$i]+$cbox) . " ";
		}
	}
	open(IMASK, "-|", "3dmaskdump $boxcmd -xyz HAFA.nii") || die "Could not open the mask file $inmask\n";

	while(<IMASK>) {
		my @line = split;
		
		my ($i, $j, $k) = @line[0,1,2];
	
		$full_mask[$i][$j][$k] = [@line[3 .. $#line]];
	
		if( $. == 1 ) {
			@max = @line;
			@min = @line;
		}
	
		for(my $f=0; $f<=$#line; $f++) {
			$max[$f] = $line[$f] if $max[$f] < $line[$f];
			$min[$f] = $line[$f] if $min[$f] > $line[$f];
		}
	}
	
	close(IMASK);
}

# Test that a neighbour voxel is within array bounds and 
# has positive intensity.
sub nbr_in_bounds
{
	my $nbr_ref = shift;
	my @nbr = @$nbr_ref;
	
	my $in_bounds = 1;
	for my $n (0..2) {
		$in_bounds = 0 if $nbr[$n] > $max[$n] || $nbr[$n] < $min[$n];
	}
	
	if( $in_bounds == 1 )
	{
		my ($i, $j, $k) = @nbr;
		my $intensity = $full_mask[$i][$j][$k][-1];
		$in_bounds = 0 if $intensity <= 0;
	}
	
	return $in_bounds;
}

# Find all 27 neighbours of a given voxel (itself included) (3x3x3 cube) and 
# return all those that have not yet been processed (self not included).
sub get_nbrs
{
	my $coord_ref = shift;
	(my $i, my $j, my $k) = @$coord_ref;

	for( my $di = -1; $di <= 1; $di++ ) {
		for( my $dj = -1; $dj <= 1; $dj++ ) {
			for( my $dk = -1; $dk <= 1; $dk++ ) {
				my @nbr = ($i+$di, $j+$dj, $k+$dk);
				push @coord_stack, [ @nbr ] if( &nbr_in_bounds(\@nbr) );
			}
		}
	}	
}

sub print_coord
{
	my ($i, $j, $k, $maskval) = @_;
	if( $outxyz ) {
		$#{$full_mask[$i][$j][$k]} == 3 or die "Can't output xyz -- not in input.\n";
		my ($x, $y, $z) = @{$full_mask[$i][$j][$k]}[0,1,2];
		print $xyz_fh "$x $y $z\n";
	}
	
	if( $outijk ) {
		print $ijk_fh "$i $j $k $maskval\n";
	}
	
	if( $outnii ) {
		push(@onii, "$i $j $k $maskval\n");
	}
}

# Given a single coord in the coord_stack, begin processing from this point
# and set all mask values for this cluster to $maskval.
sub fill_cluster
{
	my $maskval = shift;

	while( $#coord_stack >= 0 ) {
		
		my $coord_ref = pop(@coord_stack);
		my ($i, $j, $k) = @$coord_ref;
		
		print_coord($i, $j, $k, $maskval);

		# Remove the current voxel from further processing.
		$full_mask[$i][$j][$k][-1] = -1;
	
		# Get the neighbours of the current voxel onto the @coord_stack.
		&get_nbrs($coord_ref);
	}
}

&parse_cmds;
&read_mask;

foreach my $sc_ref (@start_coords)
{
	my @sc = @$sc_ref;
	my @sc_ijk = @sc[0..2];
	my $maskval = $sc[3];
	@coord_stack = (); # Empty the coord stack just in case. Should already be empty.
	push @coord_stack, [@sc_ijk];
	&fill_cluster($maskval);
}

if( $outijk ) {
	close($ijk_fh);
}
if( $outxyz ) {
	close($xyz_fh);
}
if( $outnii ) {
	open(OUT, "|-", "3dUndump -master $inmask -prefix $outnii -");
	foreach my $line (@onii) { print OUT $line }
}


