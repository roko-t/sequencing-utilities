#!/usr/local/bin/perl

#################
#
# script name  : check_sheet.pl
# author       : Hiroko Tanaka
# version      : 1.03
# date         : 2015.7.3
# description  : check SampleSheet
#
# history      : ver 1.00    2014.11.05 new edition
#              : ver 1.01    2015.03.05 modify FCID check
#              : ver 1.02    2015.06.12 add full-width charaters check
#              : ver 1.03    2015.07.03 output arguments
#
# calling seq  : check_sheet.pl run_name path_to_sample_sheet_file 
# 
# usage        : perl check_sheet.pl 141010_D00582_0030_AC5AM5ACXX /home/user/SampleSheet.csv 
# exit value   : maximum number of samples on each lane  
#
#################

#arg1 : run directory name
#arg2 : path to sample sheet file

use strict;
use warnings;
use feature 'switch';

# define
my $STR_HEADER="FCID,Lane,SampleID,SampleRef,Index,Description,Control,Recipe,Operator,SampleProject";

print "check_sheet.pl ver 01.03 date 2015.7.3 \n";

# get arguments of command line

if(@ARGV != 2 ){    # arguments num check
    my $num = @ARGV;
    my $value = join ', ', @ARGV;
    print "Invalid number of arguments ($num)\n";
    print "arguments ( $value )\n";
    die "Usage : perl check_sheet.pl <run_name> <path_to_sample_sheet>\n";
}

my $run_name = $ARGV[0];
my $in_f     = $ARGV[1];

# get FCID  
my $fc = substr( $run_name, length( $run_name ) - 9, 9 ) ; # get from run name

print "\n--- check ( $in_f ) ---\n";

# file check
unless( -e $in_f ){ # input files not exist ?
    die "input file (${in_f}) not exist.\n";
}

# system check full-width charaters  2015.6.12 added
#my $value = `grep -n -v "^[[:cntrl:][:print:]]*\$" $in_f`;  # not file with all ascii characters
#if ( $value ne "" ){
#    die "ERROR : sample sheet (${in_f}) : illegal full-width characters.\n$value \n";
#}

# file open
open(DATA_IN, $in_f) or die "input file(${in_f}) open error";

my %sample_list = ();
my %index_list = ();
my $str     = "";
my $line_cnt = 0;
my @sample_cnt = ();
my @line_array = ();
my %sample_ID = ();     # sample ID list

while( $str = <DATA_IN> ){             # 1 line read
    # cut newline character
    #   chomp $str;         # cut LF \n (0x0A) only   
    $str =~ s/\r?\n?$//;    # cut LF & CR \r (0x0D)
    print $str . "\n" ;
    next if ( $str eq "" ); # null line -> next  

    push @line_array , $str ; 
    $line_cnt++;
    
    if ( $line_cnt == 1 ){ 
        # check header
        $sample_cnt[ 0 ] = 0; 
        $str eq $STR_HEADER ? next : die "sample sheet (${in_f}) : Header failed.\n";
    }
    my @column_data = ();    
    if ( &check_format( $fc, $str, \@column_data ) ){
        die "sample sheet (${in_f}) : line[ $line_cnt ] : format error.\n";
    }

    my $lane = $column_data[ 1 ];
    $sample_ID{ $column_data[ 2 ] }++;  # get sample ID  

    # check index duplicate   
    if( exists $index_list{ $lane }{ $column_data[ 4 ] } ){
	die "sample sheet (${in_f}) : lane( $lane ) index duplicate error. \n$index_list{ $lane }{ $column_data[ 4 ] } \n$str \n";
    } else {
        $index_list{ $lane }{ $column_data[ 4 ] } = $str;
    }

    $sample_cnt[ $lane ]++;
    $sample_list{ $lane }{ $sample_cnt[ $lane ] } = $str;
    
}
close DATA_IN ;

# re-check full-width charaters 
#my @line_list = grep { /[^\x01-\x7E]/ } @line_array ; # full-width characters
#if( @line_list > 0 ){
#    my $full_line = join "\n" , @line_list ;
#    die "ERROR : sample sheet (${in_f}) : illegal full-width characters.\n$full_line \n";
#}

# get number of sample
my $num_sample = keys %sample_ID;

# check line duplicate
my %line_tmp;
my @line_list = grep( $line_tmp{$_}++, @line_array ); 
if( @line_list > 0 ){
    my $duplicated_line = join "\n" , @line_list ;
    die "ERROR : sample sheet (${in_f}) : line duplicate. \n$duplicated_line \n";
}

# check sample count every lane
for( my $i = 0 ; $i <= 8  ; $i++ ) {
    if( ! defined( $sample_cnt[ $i ] ) ){ $sample_cnt[ $i ] = 0; }  # undefined -> 0
}
my $index_str = "";
shift @sample_cnt ;  # exclude header line
my $str_sample_cnt = join ',' , @sample_cnt ;
print "sample_cnt : $str_sample_cnt \n";
my @sort_sample_cnt = sort {$b <=> $a} @sample_cnt ;
my $max_sample_cnt = $sort_sample_cnt[ 0 ];
if( $max_sample_cnt < 1 ){ 
    print "sample sheet (${in_f}) : no sample.\n";
    exit $max_sample_cnt;
} 

print "\n--- check complete ( $in_f ) ---\n";


#################
#
# sub routine : check_format
# author      : Hiroko Tanaka
# version     : 1.01
# date        : 2015.06.12
# discription : check the format of SampleSheet
#
# history     : Ver 1.00 2013.08.08 new edition
#             : Ver 1.01 2015.06.12 check full-width characters
#
# arg1        : Flowcell ID ( 9 charcters ,e.g. D2EK5ACXX )
# arg2        : line string of SampleSheet ( 10 items )( FCID,Lane,SampleID,SampleRef,Index,Description,Control,Recipe,Operator,SampleProject )
#               e.g. D256YACXX,4,SSP25NA18943_exome_Libpool_20130720_01,Human,CAGAGA,,,"101,7,101",nakano,icgc_exome 
#
# example     : check_format( "D2EK5ACXX", str_line, @sheet_data  )
#
# return      : 0 : OK
#             : 1 : error
#
#################
sub check_format {

    # get arguments    
    my ( $fc, $str_line, $sheet_data) = @_;
#    print "FC:$fc, line:$str_line" , "\n";

    # error message
    my $ERR_NUM_FIELD  = "Wrong number of fields ( It should be 10.)  ";
    my $ERR_FC_ID      = "Warning FCID ( It should be $fc.)  ";
    my $ERR_LANE_NO    = "Wrong number of Lane ( It should be 1-8.)  ";
    my $ERR_CHARACTERS = "SampleID or SampleProject name contains illegal characters.(the space character and the following: ? ( ) [ ] / \ = + < > : ; \" ' , * ^ | & .)  ";
    my $ERR_INDEX_CHAR = "Index contains illegal characters. ( not A,C,G,T )  ";
    my $ERR_FULL_CHAR  = "SampleID or SampleProject name contains illegal full-width characters.";
    my @line = split( /\,/, $str_line );  # split by comma

    # get sheet data 
    my $index = 0;
    my $str_tmp = ""; 
    my $wquoto = 0;
    for( my $i = 0 ; $i < @line ; $i++ ){
 #       print $line[ $i ] . "\n" ;
 #       print "wquoto : $wquoto  \n" ;
        if( $line[ $i ] =~ /\"/ ){  # find double quoto ?
            $wquoto = $wquoto == 1 ? 0 : 1 ;
 #           print "find -> wquoto : $wquoto  \n" ;
        }
        if( $wquoto == 1 ){
            $str_tmp .= $line[ $i ] ;
	} else {
            if( $str_tmp eq "" ){
                $$sheet_data[ $index ] = $line[ $i ]; 
            } else {
                $$sheet_data[ $index ] = $str_tmp . $line[ $i ];
                $str_tmp = "";                        # clear temporary string
	    }
            $index++ ;
#           print "index : $index  \n" ;
	}
    }
    
    # check num of column
    if( $index != 10 ){
        print $ERR_NUM_FIELD . "[ $index ]" , "\n";
        return 1 ;
    }

    # check format
    for( my $i = 0 ; $i < $index ; $i++ ){
        given( $i ){
            when( 0 ){ # FCID
                if( $$sheet_data[ $i ] ne $fc ){
                    print $ERR_FC_ID . "[ $$sheet_data[ $i ] ]" , "\n";
#                    return 1 ;
#                    return 0 ;  # 2015.3.5 error -> warning  2016.6.12 no return
                } 
            }
	    when( 1 ){ # Lane : Positive integer, indicating the lane number (1-8)
                if( $$sheet_data[ $i ] !~ /^[1-8]{1}$/ ){
                    print $ERR_LANE_NO . "[ $$sheet_data[ $i ] ]" , "\n";
		    return 1 ;
	        }
            }
	    when( $i == 2 || $i == 9 ){ # SampleID or SampleProject
                # The characters not allowed are the space character and the following:
                # ? ( ) [ ] / \ = + < > : ; " ' , * ^ | & .
                if( $$sheet_data[ $i ] =~ /[\?\(\)\[\]\/\\\=\+\<\>\:\;\"\'\,\*\^\|\&\.\s]+/ ){ 
                    print $ERR_CHARACTERS . "[ $$sheet_data[ $i ] ]" , "\n";
                    return 1 ;
                }
# test          print  "[ $$sheet_data[ $i ] ]" , "\n";
                # full-width characters  2015.6.12 added
                if( $$sheet_data[ $i ] =~ /[^\x01-\x7E]+/ ){
                    print $ERR_FULL_CHAR . "[ $$sheet_data[ $i ] ]" , "\n";
                    return 1 ;
                } 
            }
            when( 3 ){ # SampleRef
            }
            when( 4 ){ # Index
                # The characters are A,C,G,T & -.
                if( $$sheet_data[ $i ] =~ /[^ACGT-]+/i ){
                    print $ERR_INDEX_CHAR . "[ $$sheet_data[ $i ] ]" , "\n";
                    return 1 ;
                }
            }
	    when( 5 ){ # Description
            }
	    when( 6 ){ # Control
            }
	    when( 7 ){ # Recipe
            }
	    when( 8 ){ # Operator
            }
	    when( 9 ){ # SampleProject
            } 
            default{
                print $ERR_NUM_FIELD . "[ $index ]" , "\n";
	        return 1 ;
            }
	}
    }

    return 0 ;
}

      


