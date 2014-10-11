#/usr/bin/env perl
use strict;

##########
## Assess paths from iSG runs. <filename> = XXXXXX.epc.paths
##########
if (@ARGV != 4) { die "Usage: perl assess_paths <delta_t> <path_filename> <first_cycle_to_sample> <sample_each_x_cycles>\n"; }
my ($delta_t, $filename, $first_cycle_to_sample, $sample_each_x_cycles) = @ARGV;
my ($numStates);
$numStates = 4; 	## For now, assume nucleotides. Can change to codons or higher order contexts later. ##
my ($t_0, $T) = (0, 1);		## Known, for the time being. ##
my $time_bins = 10000;
#my $time_bins = 1000;
my $time_increment = ($T - $t_0) / $time_bins;
my $max_path_diff = 0;
my $min_diff = 1;
my $max_diff = 0;
my $num_sampled_paths = 0;
my @all_path_diff = ();
my @distance_matrix = ();
my $EPC = 0;
my ($global_min, $global_max) = (10000, 0);

{ ######### MAIN #########

	open my $infile, '<', $filename or die "Cannot open file $filename: $?\n";
	my ($tree, $sequence_data, $initial_cycle) = &read_init($infile);
	my ($i_0, $k_0, $sequence_size) = &set_endpoints($sequence_data);

	## Output MCMC cycle data for heat map. ##
	$time_bins = 1000;
	&output_mcmc_heatmap_table($infile, $i_0, $t_0, $T, $time_increment, $time_bins, $initial_cycle, $first_cycle_to_sample);
	print STDERR "min: $global_min     max: $global_max\n";

	exit(0);

	##########
	## 2-pass data: First pass through data, construct average path.
	##########
	my (@average_path);
	seek $infile, 0, 0;
	open my $infile, '<', $filename or die "Cannot open file $filename: $?\n";
	&read_init($infile);

	## Average path calculation. ##
	&build_average_path(\@average_path, $time_bins, $sequence_size, $numStates);
	&calculate_average_path(\@average_path, $infile, $i_0, $t_0, $T, $time_increment, $time_bins, $initial_cycle, $first_cycle_to_sample);
	&normalize_profile(\@average_path, $time_bins, $sequence_size, $numStates);
	&print_profile(\@average_path, $time_bins, $sequence_size, $numStates);

	##########
	## Second pass through data, running individual sequence paths against average sequence path.
	##########
	seek $infile, 0, 0;
	&read_init($infile);	## Set to first path ##
	&compare_to_average_path(\@average_path, $infile, $i_0, $t_0, $T, $time_increment, $time_bins, $initial_cycle, $first_cycle_to_sample);
	my ($mean, $stdev) = &mu_sigma(\@all_path_diff);

	##########
	## Third pass through data, running individual sequence paths against individual sequence path.
	##########
#	open my $col_infile, '<', $filename or die "Cannot open file $filename: $?\n";	## Infile for 2nd seq. ##
#	seek $infile, 0, 0;
#	&read_init($infile);	## Set to first path ##
#	&build_distance_matrix(\@distance_matrix, $num_sampled_paths);
#	&compare_individual_paths(\@distance_matrix, $infile, $col_infile, $i_0, $t_0, $T, $time_increment, $time_bins, $initial_cycle, $first_cycle_to_sample);

	print STDERR "\navg sequence mean: $mean stdev: $stdev\n";
} ### End main ###

sub build_distance_matrix
{
	my ($distmat_ref, $num_paths) = @_;
	my @array;
	for my $i ( 0 .. $num_paths ) {
		$distmat_ref->[$i] = [ @array ];
		for my $j ( 0 .. $num_paths ) {
			$distmat_ref->[$i][$j] = 0;
		}
	}
}

##########
### Compare each individual path against all other paths. Build the distance matrix.
sub compare_individual_paths
{
	my ($distmat_ref,
		$rowfh,
		$colfh,
		$i_0,
		$t_0,
		$T,
		$time_increment,
		$time_bins,
		$initial_cycle,
		$first_cycle_to_sample
	   ) = @_;

	my ($row_idx, $col_idx) = (0,0);	## Row and column index for the dist matrix. ##

	my ($rpath, $rcurrent_cycle, $rnextpath_cycle)
	= &advance_to_first_sample(
							   $rowfh,
							   $initial_cycle,
							   $first_cycle_to_sample
							  );
	## Next sample is set to -1 when there are no more paths to be read from MCMC
	## After reading to the next path, we will have the next pathID (cycle for which it was accepted),
	## and the previous path (since next pathID will be larger than the current cycle).
	my (@seq1_work, @seq2_work);
	for ($row_idx = 0; $rnextpath_cycle != -1; $row_idx++) {
		### Get the next path ###
		($rpath, $rnextpath_cycle, $rcurrent_cycle) = &get_next_sample(
						   											   $rowfh,
																       $rcurrent_cycle,
										 						       $sample_each_x_cycles,
						  										 	   $rpath,
						   											   $rnextpath_cycle
							 									      );
		## Place column pointer on "diagonal" of the dist matrix (point to same record as row). ##
		seek $colfh, 0, 0;
		my ($cpath, $cnextpath_cycle, $ccurrent_cycle)
		= &advance_to_first_sample(
								   $colfh,
								   $initial_cycle,
								   $first_cycle_to_sample
								  );
		$col_idx = 0;
		&compare_sequences($i_0, $t_0, $T, $rpath, $cpath, \@distance_matrix, $row_idx, $col_idx, $time_increment, $time_bins);
		for ($col_idx = 1; $cnextpath_cycle != -1; $col_idx++) {
			### Get next path ###
			($cpath, $cnextpath_cycle, $ccurrent_cycle) = &get_next_sample(
							   											   $colfh,
																	       $ccurrent_cycle,
											 						       $sample_each_x_cycles,
							  										 	   $cpath,
							   											   $cnextpath_cycle
								 									   	  );
			### Compare sampled sequences ###
			&compare_sequences($i_0, $t_0, $T, $rpath, $cpath, \@distance_matrix, $row_idx, $col_idx, $time_increment, $time_bins);
		}
	}
}

my @Qidot_avg = ();

sub output_mcmc_heatmap_table
{
	my ($fh, $i_0, $t_0, $T, $time_increment, $time_bins, $initial_cycle, $first_cycle_to_sample) = @_;

	my ($path, $current_cycle, $nextpath_cycle) = &advance_to_first_sample($fh, $initial_cycle, $first_cycle_to_sample);
	## Next sample is set to -1 when there are no more paths to be read from MCMC
	## After reading to the next path, we will have the next pathID (cycle for which it was accepted),
	## and the previous path (since next pathID will be larger than the current cycle).
	my (@work);
	my $num_samples = 0;
	while ($nextpath_cycle != -1) {
		### Set the work sequence to the initial state ###
		@work = split //, $i_0;
		### Get the next path ###
		($path, $nextpath_cycle, $current_cycle)
		= &get_next_sample(
						   $fh,
						   $current_cycle,
						   $sample_each_x_cycles,
						   $path,
						   $nextpath_cycle
						  );
		## Should have path to profile && cycle of interest.
		print STDERR "$current_cycle $nextpath_cycle\n";
		#print STDERR $path . "\n";
		print "cycle_$current_cycle";
		&print_path($i_0, $t_0, $T, $path, $time_increment, $time_bins);
		#if ($current_cycle > 200) {exit(0);}
		$num_samples++;
	}

	open OUT, ">avg_of_paths";
	print OUT "xyz\t";
	for my $j (0 .. 9999) {
		print OUT "\t" . ($Qidot_avg[$j]/$num_samples);
	}
	close OUT;

	exit(0);
}

sub print_path
{
	my (
		$i_0,				## Begin sequence.
		$t_0, 				## Start time of i_0 (begin time before time_bin increments).
		$T,					## End time.
		$path_to_add, 		## Path from $i_0--->$k_0
		$dt,				## Amount of time to increment at each step.
		$total_time_bins	## To increment the array at the proper point.
	   ) = @_;

	my @path_events = split /\n/, $path_to_add;
	pop @path_events;		## Branch ending event. ##
	my @work_sequence = split //, $i_0;
	my $last_event_ptr = 0;
	my ($prof_site_idx) = (0);

	my $times_thru_wasted_loop = 0;
	my $num_print = 0;

	my $Qidot_avg_idx = 0;

	my ($t, $change, $Qidot, $site, $Qidot_k);
	($t, $site, $change, $Qidot, $Qidot_k) = split(",", $path_events[$last_event_ptr]);
	my $last_Q = $Qidot;
	if ($EPC) { $last_Q = $Qidot_k; }
	for (my $time_bin = $t_0; $time_bin < $T; $time_bin += $dt) {
		## Catch work sequence up to the times.
		if ($last_event_ptr > @path_events - 1) {
			#print "$time_bin -> $t ";
			if ($last_Q < $global_min) { $global_min = $last_Q; }
			if ($last_Q > $global_max) { $global_max = $last_Q; }
			print "\t$last_Q";
			$Qidot_avg[$Qidot_avg_idx++] += $last_Q;
			$num_print++;
			#print "!!!\n";
		} else {
			while ($time_bin < $t) {
				#print "$time_bin -> $t ";
				if ($EPC) {
					if ($Qidot_k < $global_min) { $global_min = $Qidot_k; }
					if ($Qidot_k > $global_max) { $global_max = $Qidot_k; }
					print "\t$Qidot_k";
					$Qidot_avg[$Qidot_avg_idx++] += $Qidot_k;
				} else {
					if ($Qidot < $global_min) { $global_min = $Qidot; }
					if ($Qidot > $global_max) { $global_max = $Qidot; }
					print "\t$Qidot";
					$Qidot_avg[$Qidot_avg_idx++] += $Qidot;
				}

				$num_print++;
				#print "***\n";
				$time_bin+=$dt;
			}

			my $num_in_bin = 1;
			my ($t2, $site2, $change2, $Qidot2, $Qidot_k2) = split(",", $path_events[$last_event_ptr+1]);
			if ($t2 < $time_bin && $t2 > $t && $t != 0) {
				my $bin_val = $Qidot;
				while ($t2 < $time_bin && $t2 > $t) {
					($t2, $site2, $change2, $Qidot2, $Qidot_k2)
					= split(",", $path_events[$last_event_ptr+$num_in_bin]);
					if ($EPC) {
						$bin_val += $Qidot_k2;
					} else {
						$bin_val += $Qidot2;
					}
					$num_in_bin++;
				}

				$Qidot = $bin_val / $num_in_bin;
				if ($EPC) {
					if ($Qidot_k < $global_min) { $global_min = $Qidot_k; }
					if ($Qidot_k > $global_max) { $global_max = $Qidot_k; }
					print "\t$Qidot_k";
					$Qidot_avg[$Qidot_avg_idx++] += $Qidot_k;
				} else {
					if ($Qidot < $global_min) { $global_min = $Qidot; }
					if ($Qidot > $global_max) { $global_max = $Qidot; }
					print "\t$Qidot";
					$Qidot_avg[$Qidot_avg_idx++] += $Qidot;
				}
				$num_print++;
				#print "???\n";
				$times_thru_wasted_loop++;
			} else {
				#print "$time_bin -> $t ";
				if ($EPC) {
					if ($Qidot_k < $global_min) { $global_min = $Qidot_k; }
					if ($Qidot_k > $global_max) { $global_max = $Qidot_k; }
					print "\t$Qidot_k";
					$Qidot_avg[$Qidot_avg_idx++] += $Qidot_k;
				} else {
					if ($Qidot < $global_min) { $global_min = $Qidot; }
					if ($Qidot > $global_max) { $global_max = $Qidot; }
					print "\t$Qidot";
					$Qidot_avg[$Qidot_avg_idx++] += $Qidot;
				}
				$num_print++;
				#print "~~~\n";
				if ($Qidot != 0) { $last_Q = $Qidot; }
			}

			## Finished event, get data of next event.
			$last_event_ptr += $num_in_bin;
			($t, $site, $change, $Qidot, $Qidot_k) = split(",", $path_events[$last_event_ptr]);
			#print "$last_event_ptr: $t $site $change $Qidot $Qidot_k\n";
		}
	}

	print STDERR "Qidot_avg_idx = $Qidot_avg_idx\n";

	print "\n";
	print STDERR "$num_print\n";
}

sub compare_sequences
{
	my (
		$i_0,				## Begin sequence.
		$t_0, 				## Start time of i_0 (begin time before time_bin increments).
		$T,					## End time.
		$path1, 			## Row path from $i_0--->$k_0
		$path2, 			## Col path from $i_0--->$k_0
		$distmat_ref, 		## 2D array, distance matrix.
		$row_idx,			## Row index
		$col_idx,			## Column index
		$dt,				## Amount of time to increment at each step.
		$total_time_bins	## To increment the array at the proper point.
	   ) = @_;


	my @path1_events = split /\n/, $path1;
	my @seq1 = split //, $i_0;

	my @path2_events = split /\n/, $path2;
	my @seq2 = split //, $i_0;

	pop @path1_events;
	pop @path2_events;

	my $rlast_event_ptr = 0;
	my $clast_event_ptr = 0;
	my ($prof_site_idx) = (0);
	my $path_diff = 0;
	$max_path_diff = 0;

	## Get first event data for both row and column sequence indices
	my ($rt, $rsite, $rchange, $rQidot, $rQidot_k) = split(",", $path1_events[$rlast_event_ptr]);
	my ($ct, $csite, $cchange, $cQidot, $cQidot_k) = split(",", $path2_events[$clast_event_ptr]);

	for (my $time_bin = $t_0; $time_bin < $T; $time_bin += $dt) {
		## Catch row sequence up to the times.
		while ($rt < $time_bin and $rlast_event_ptr < @path1_events ) {
			## Make change to sequence
			my @nucl_pair = split //, $rchange;
			if ($seq1[$rsite] ne $nucl_pair[0]) { die "Odd... $seq1[$rsite] != $nucl_pair[0].\n"; }
			else { $seq1[$rsite] = $nucl_pair[1]; }
			$rlast_event_ptr++;
			($rt, $rsite, $rchange, $rQidot, $rQidot_k) = split(",", $path1_events[$rlast_event_ptr]);
		}
		## Catch row sequence up to the times.
		while ($ct < $time_bin and $clast_event_ptr < @path2_events ) {
			## Make change to sequence
			my @nucl_pair = split //, $cchange;
			if ($seq2[$csite] ne $nucl_pair[0]) { die "Odd... $seq2[$csite] != $nucl_pair[0].\n"; }
			else { $seq2[$csite] = $nucl_pair[1]; }
			$clast_event_ptr++;
			($ct, $csite, $cchange, $cQidot, $cQidot_k) = split(",", $path2_events[$clast_event_ptr]);
		}

		## Add sequence differences to the distance matrix ##
		$distmat_ref->[$row_idx][$col_idx] += &seq_diff(\@seq1, \@seq2);
	}

	print "$row_idx $col_idx $distmat_ref->[$row_idx][$col_idx]\n";
}

sub seq_diff
{
	my ($seq1_ref, $seq2_ref) = @_;
	my $diff = 0;
	for my $i (0 .. @{ $seq1_ref }-2) {
		if ($seq1_ref->[$i] ne $seq2_ref->[$i]) { $diff++; }
	}
	return $diff;
}

sub advance_to_first_sample
{
	my ($fh, $initial_cycle, $first_cycle_to_sample) = @_;

	##########
	### Have basic data structures, now need to put together the MCMC runs.
	##########
	my (
		$nextpath_cycle,## When < current_cycle, stored path is invalid. New path needed.
		@tmp, 			## Exactly what it says it is.
		$current_cycle, ## Current cycle, value will be (($cc-$first_cycle_to_sample)% sample_x_cycles == 0)
		$path, 			## Path previous to $next_cycle path.
	   );
	$current_cycle = $nextpath_cycle = $initial_cycle;

	## Read paths until reaching the first potential cycle to sample.
	while($nextpath_cycle < $first_cycle_to_sample and !eof($fh)) {
		($path, $nextpath_cycle) = &get_next_path($fh);
	}
	## In the end, set current_cycle to the first cycle to sample. This is because there may be
	## non-accepted paths before the first true path to sample, which could potentially skip a
	## number of possible samples of the "current" path state.
	$current_cycle = $first_cycle_to_sample;
	($path, $nextpath_cycle) = &get_next_sample($fh, $current_cycle, $sample_each_x_cycles);

	return ($path, $current_cycle, $nextpath_cycle); # Path corresponding to the first cycle to sample.
}

sub compare_to_average_path
{
	my ($profile_ref, $fh, $i_0, $t_0, $T, $time_increment, $time_bins, $initial_cycle, $first_cycle_to_sample) = @_;

	my ($path, $current_cycle, $nextpath_cycle) = &advance_to_first_sample($fh, $initial_cycle, $first_cycle_to_sample);
	## Next sample is set to -1 when there are no more paths to be read from MCMC
	## After reading to the next path, we will have the next pathID (cycle for which it was accepted),
	## and the previous path (since next pathID will be larger than the current cycle).
	my (@work);
	while ($nextpath_cycle != -1) {
		### Set the work sequence to the initial state ###
		@work = split //, $i_0;
		### Get the next path ###
		($path, $nextpath_cycle, $current_cycle)
		= &get_next_sample(
						   $fh,
						   $current_cycle,
						   $sample_each_x_cycles,
						   $path,
						   $nextpath_cycle
						  );
		## Should have path to profile && cycle of interest.
		print "$current_cycle ";
		&compare_to_profile($i_0, $t_0, $T, $path, $profile_ref, $time_increment, $time_bins);
	}
}

sub compare_to_profile
{
	my (
		$i_0,				## Begin sequence.
		$t_0, 				## Start time of i_0 (begin time before time_bin increments).
		$T,					## End time.
		$path_to_add, 		## Path from $i_0--->$k_0
		$profile_array_ref, ## 3D array, from above.
		$dt,				## Amount of time to increment at each step.
		$total_time_bins	## To increment the array at the proper point.
	   ) = @_;

	my @path_events = split /\n/, $path_to_add;
	pop @path_events;		## Branch ending event. ##
	my @work_sequence = split //, $i_0;
	my $last_event_ptr = 0;
	my ($prof_site_idx) = (0);

	my $path_diff = 0;
	$max_path_diff = 0;
	my ($t, $change, $Qidot, $site, $Qidot_k);
	($t, $site, $change, $Qidot, $Qidot_k) = split(",", $path_events[$last_event_ptr]);
	for (my $time_bin = $t_0; $time_bin < $T; $time_bin += $dt) {
		## Catch work sequence up to the times.
		while ($t < $time_bin and $last_event_ptr < @path_events ) {
			## Make change to sequence
			my @nucl_pair = split //, $change;
			if ($work_sequence[$site] ne $nucl_pair[0]) { die "Odd... $work_sequence[$site] != $nucl_pair[0].\n"; }
			else { $work_sequence[$site] = $nucl_pair[1]; }

			## Finished event, get data of next event.
			$last_event_ptr++;
			($t, $site, $change, $Qidot, $Qidot_k) = split(",", $path_events[$last_event_ptr]);
			#print "$last_event_ptr: $t $site $change $Qidot $Qidot_k\n";
		}
		$path_diff += &profile_diff($profile_array_ref, \@work_sequence, $time_bin * $total_time_bins);
	}

	$num_sampled_paths++;

	##########
	### Normalize value by dividing by independent variables (sequence length, # time bins)
	##########
	$path_diff /= $total_time_bins * 1000; # 1000 is sequence length...

	$all_path_diff[$num_sampled_paths] = $path_diff;
	if ($path_diff > $max_diff) { $max_diff = $path_diff; }
	if ($path_diff < $min_diff) { $min_diff = $path_diff; }
	print " $path_diff\n";
}

sub profile_diff
{
	my ($prof_ref, $seqdata_ref, $time_idx) = @_;

	my $diff = 0;
	for my $i (0 .. @{ $seqdata_ref }-2) {
		$diff += 1 - $prof_ref->[$time_idx] [$i] [&pattern_idx($seqdata_ref->[$i])];
		$max_path_diff++;
	}

	return $diff;
}

sub calculate_average_path
{
	my ($profile_ref, $fh, $i_0, $t_0, $T, $time_increment, $time_bins, $initial_cycle, $first_cycle_to_sample) = @_;

	my ($path, $current_cycle, $nextpath_cycle) = &advance_to_first_sample($fh, $initial_cycle, $first_cycle_to_sample);
	## Next sample is set to -1 when there are no more paths to be read from MCMC
	## After reading to the next path, we will have the next pathID (cycle for which it was accepted),
	## and the previous path (since next pathID will be larger than the current cycle).
	my (@work);
	while ($nextpath_cycle != -1) {
		### Set the work sequence to the initial state ###
		@work = split //, $i_0;
		### Get the next path ###
		($path, $nextpath_cycle, $current_cycle)
		= &get_next_sample(
						   $fh,
						   $current_cycle,
						   $sample_each_x_cycles,
						   $path,
						   $nextpath_cycle
						  );
		## Should have path to profile && cycle of interest.
		print STDERR "$current_cycle $nextpath_cycle\n";
		&add_to_profile($i_0, $t_0, $T, $path, $profile_ref, $time_increment, $time_bins);
	}
}

sub build_average_path
{
	my ($profile_ref, $time_bins, $sequence_size, $numStates) = @_;

	my (@array);
	##########
	## Build AVERAGE PATH array. 3D array, $average_path[D1][D2][D3], where
	## D1 = time_bin
	## D2 = Sequence_site
	## D3 = state at site (A,C,G,T) for 0-th order MM, (A|A, A|C, ..., T|G, T|T) for 1-st order MM, etc.
	##########
	for my $i ( 0 .. $time_bins ) {
		$profile_ref->[$i] = [ @array ];
		for my $j (0 .. $sequence_size-1) {
			$profile_ref->[$i][$j] = [ @array ];
			for my $k (0 .. $numStates) {
				$profile_ref->[$i][$j][$k] = 0;
			}
		}
	}
}

sub read_init
{
	my ($fh) = @_;

	my $tree = <$fh>;
	my $sequence_data = "";
	my $initial_cycle;

	### Read to the first path. after the tree & before the first path comes the end-point sequences. ###
	($sequence_data, $initial_cycle) = &get_next_path($fh);

	return ($tree, $sequence_data, $initial_cycle);
}

sub set_endpoints
{
	my ($seqdata) = @_;

	my ($i_0, $k_0, @work, @each_seq, $sequence_size);
	@each_seq = split />.+\n/, $seqdata;
	$i_0 = $each_seq[1];
	$k_0 = $each_seq[2];
	@work = split //, $i_0;
	$sequence_size = scalar @work;

	return ($i_0, $k_0, $sequence_size);
}

sub print_profile
{
	my ($prof_ref, $time_bins, $sequence_size, $numStates) = @_;

	open OUT, ">avg_path.stat";

	for my $i ( 0 .. $time_bins ) {
		for my $j (0 .. $sequence_size-1) {
			for my $k (0 .. $numStates) {
				print OUT "$i $j $k $prof_ref->[$i][$j][$k]\n";
			}
		}
	}
	close OUT;
}

sub normalize_profile
{
	my ($prof_ref, $time_bins, $sequence_size, $numStates) = @_;

	for my $i ( 0 .. $time_bins ) {
		for my $j (0 .. $sequence_size-1) {
			my $num_hits = 0;
			for my $k (0 .. $numStates) {
				$num_hits += $prof_ref->[$i][$j][$k];
			}

			if ($num_hits != 0) {
				for my $k (0 .. $numStates) {
					$prof_ref->[$i][$j][$k] /= $num_hits;
				}
			}
		}
	}
}

sub add_to_profile
{
	my (
		$i_0,				## Begin sequence.
		$t_0, 				## Start time of i_0 (begin time before time_bin increments).
		$T,					## End time.
		$path_to_add, 		## Path from $i_0--->$k_0
		$profile_array_ref, ## 3D array, from above.
		$dt,				## Amount of time to increment at each step.
		$total_time_bins	## To increment the array at the proper point.
	   ) = @_;

	my @path_events = split /\n/, $path_to_add;
	pop @path_events;		## Branch ending event. ##
	my @work_sequence = split //, $i_0;
	my $last_event_ptr = 0;
	my ($prof_site_idx) = (0);

	my ($t, $change, $Qidot, $site, $Qidot_k);
	($t, $site, $change, $Qidot, $Qidot_k) = split(",", $path_events[$last_event_ptr]);
	for (my $time_bin = $t_0; $last_event_ptr < (scalar @path_events); $time_bin += $dt) {
		## Catch work sequence up to the times.
		while ($t < $time_bin and $last_event_ptr < (scalar @path_events) ) {
			## Make change to sequence
			my @nucl_pair = split //, $change;
			if ($work_sequence[$site] ne $nucl_pair[0]) { die "Odd... $work_sequence[$site] != $nucl_pair[0].\n"; }
			else { $work_sequence[$site] = $nucl_pair[1]; }

			&increment_profile($profile_array_ref, \@work_sequence, $time_bin * $total_time_bins);

			## Finished event, get data of next event.
			$last_event_ptr++;
			($t, $site, $change, $Qidot, $Qidot_k) = split(",", $path_events[$last_event_ptr]);
			#print "$last_event_ptr: $t $site $change $Qidot $Qidot_k\n";
		}
	}
}

sub increment_profile
{
	my ($prof_ref, $seqdata_ref, $time_idx) = @_;

	for my $i (0 .. @{ $seqdata_ref }-2) {
		$prof_ref->[$time_idx] [$i] [&pattern_idx($seqdata_ref->[$i])]++;
		#print "prof_ref->[$time_idx][$i][(&pattern_idx($seqdata_ref->[$i]))]++\n";
	}
}

sub pattern_idx
{
	my ($pattern) = @_;
	my @elements = split //, $pattern;

	## Naturally, this will have to be better done for higher order Markov models.
	if ($elements[0] eq "A") { return 0; }
	if ($elements[0] eq "C") { return 1; }
	if ($elements[0] eq "G") { return 2; }
	if ($elements[0] eq "T") { return 3; }
	else { die "Unknown element for pattern index: \"$elements[0]\"\n"; }
}

#########
### This will set the file to the appropriate next sample.
#########
sub get_next_sample
{
	my ($fh, $current_cycle, $sample_each_x_cycles, $path, $next_path_cycle) = @_;

	$current_cycle += $sample_each_x_cycles;

	## Sample falls beyond current cycle.
	if ($current_cycle > $next_path_cycle) {
		while ($next_path_cycle < $current_cycle && !eof($fh)) {
			($path, $next_path_cycle) = &get_next_path($fh);
		}
	}

	if (eof($fh)) { $next_path_cycle = -1; }

	return ($path, $next_path_cycle, $current_cycle);
}

sub get_next_path
{
	my $fh = shift;
	my ($path, $pathID);
	my $line;

	my $cont = 1;
	while ($cont and $line = <$fh>) {
		if ($line !~ m/^\#/) {
			$path .= $line;
		} else { $cont = 0; }
	}

	my @tmp = split /\#/, $line;
	$pathID = $tmp[1];
	chomp($pathID);

	return ($path, $pathID);
}

sub mu_sigma
{
	my ($ref) = @_;

	my ($average, $stdev);

	for my $i (0 .. @{ $ref }-1) {
		$average += $ref->[$i];
	}

	$average /= scalar(@{ $ref });

	for my $i (0 .. @{ $ref }-1) {
		$stdev += ($average - $ref->[$i]) * ($average - $ref->[$i]);
	}

	$stdev /= scalar(@{ $ref });

	return ($average, sqrt($stdev));
}
