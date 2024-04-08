#!/usr/bin/perl
use strict;
use warnings;
use Time::HiRes qw(gettimeofday);
use Time::Local;
use File::stat;

# file housekeeping module 
#
# Version 1.0.0 
#     - Initial Version
#     - Format example: test_202404081359.csv


##### START: Define constants
use constant VERSION => '1.0.0';
use constant PROGRAM_NAME => 'housekeeping_tool';
use constant INIFILE => '/home/housekeeping_tool.ini';
##### END: Define constants

##### Read INI file
my %cfg = ();
if (-e INIFILE) {
    %cfg = &fill_ini(INIFILE);
} else {
    print "Error: Config file not found on system " . INIFILE ."\n";
    print "Usage: " . PROGRAM_NAME . "\n";
    print "Version: " . VERSION . "\n";
    print "\n";
    exit();
}
#####

##### Bring in [system] variables
my $target_dir = $cfg{'system'}->{'target_dir'};
my $keep_type = $cfg{'system'}->{'keep_type'};
my $keep_count = $cfg{'system'}->{'keep_count'};
if ($keep_count !~ /^\d+$/ || $keep_count <= 0) {
    $keep_count = 1; 
    print "keep_count illegal. (default = 1)\n"
}

if (!(-e $target_dir)) {
    print "Error: Missing log directory $target_dir\n";
    print "Usage: " . PROGRAM_NAME . "\n";
    print "Version: " . VERSION . "\n";
    print "\n";
    exit();
}


# Start 
my ($seconds, $microseconds) = gettimeofday();
my $current_time = $seconds;

opendir(my $dir_fh, $target_dir) or die "Can not open $target_dir: $!";
my @files = grep { -f "$target_dir/$_" } readdir($dir_fh);
closedir($dir_fh);

# foreach my $file (@files) {
#     print "$file\n";
# }


my @files_to_delete;
if ($keep_type eq 'day') {
    # delete_by_day($target_dir, $current_time, $keep_count, @files);
    delete_by_day_timestamp($target_dir, $current_time, $keep_count, @files);
} elsif ($keep_type eq 'count') {
    delete_by_count($target_dir, $keep_count, @files);
} else{
    print "keep_type error\n";
    exit();
}


# Delete
if (@files_to_delete){
    print "files_to_delete:\n";
    foreach my $file (@files_to_delete) {
        print "File deleted: $file \n";
        unlink "$target_dir/$file" or warn "Can not delete  $target_dir/$file: $!";
    }
} else{
    print "No files to delete.\n"
}




sub fill_ini (\$)
{
    my ($array_ref) = @_;
    my $configfile = $array_ref;

    my %hash_ref;

    # print "SUB:CONFIGFILE:$configfile\n";
    open(CONFIGFILE,"< $configfile");
    my $main_section = 'main';
    my ($line, $copy_line);

    while ($line=<CONFIGFILE>) {
        chomp($line);
        $line =~ s/\n//g;
        $line =~ s/\r//g;
        $copy_line = $line;
        if ($line =~ /^#/) {
            # Ignore starting hash
        } else {
            if ($line =~ /\[(.*)\]/) {
                # print "SUB:FOUNDSECTION:$1\n";
                $main_section = $1;
            }
            if ($line eq "") {
                # print "SUB:BLANKLINE\n";
            }
            if ($line =~ /(.*)=(.*)/) {
                my ($key,$value) = split /=/, $copy_line, 2;
                # my ($key,$value) = split('=', $copy_line);
                $key =~ s/ //g;
                $key =~ s/\t//g;
                $value =~ s/^\s+//g;
                $value =~ s/\s+$//g;
                # print "SUB:KEYPAIR:$main_section -> $key -> $value\n";
                $hash_ref{"$main_section"}->{"$key"} = $value;
            }

        }
    }
    close(CONFIGFILE);

    # $ftphost = $hash_ref{'ftp'}->{'ftphost'};
    # print "SUB:FTPHOST:$ftphost\n";

    return %hash_ref;
}

sub delete_by_day {
    my ($target_dir, $current_time, $keep_count, @files) = @_;
    foreach my $file (@files) {
        my $file_time = (stat("$target_dir/$file"))->mtime;
        if ($current_time - $file_time >= $keep_count * 86400) {
            push @files_to_delete, $file;
        }
    }
}

sub delete_by_day_timestamp {
    my ($target_dir, $current_time, $keep_count, @files) = @_;
    foreach my $file (@files) {
        my ($timestamp) = $file =~ /_(\d{12})/; 
        if ($timestamp) {
            my ($year, $mon, $mday, $hour, $min) = ($timestamp =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})$/);
            my $file_time = timelocal(0, $min, $hour, $mday, $mon-1, $year-1900); 
            if ($current_time - $file_time >= $keep_count * 86400) {
                push @files_to_delete, $file;
            }
        }
    }
}

sub delete_by_count {
    my ($target_dir, $keep_count, @files) = @_;
    my @sorted_files = sort { (my ($a_ts) = $a =~ /_(\d+)/) <=> (my ($b_ts) = $b =~ /_(\d+)/) } @files;
    if (@sorted_files > $keep_count) {
        @files_to_delete = @sorted_files[0 .. @sorted_files - $keep_count - 1];
    }
}


