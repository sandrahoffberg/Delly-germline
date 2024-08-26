#!/usr/bin/env bash

if [ $# -eq 0 ]; then
    echo "No arguments supplied"
else
    echo "args:"
    for i in $*; do 
        echo $i 
    done
    echo ""
fi



# URL of the s3 bucket with bams for analysis
if [ -z ${1} ]; then
    num_bam_files=$(find -L ../data -name "*.bam" | wc -l)
    if [ ${num_bam_files} -gt 0 ]; then
        echo "Using bams in the /data folder"
        data_dir="../data"
    else
        echo "There are no sample files available for this capsule.  Please either add some to the /data folder or provide a URL to an S3 bucket."
        exit 1
    fi
else
    s3_url=${1}
    
    # location to download the bams
    if [ -z ${2} ]; then
        data_dir=../scratch/data
    else
        data_dir=${2}
    fi
    
    #get BAM file(s) that have been trimmed, aligned to reference, sorted, read groups adjusted if necessary, and indexed
    echo "Downloading data from the S3 bucket at the provided URL."
    aws s3 sync --no-sign-request --only-show-errors ${s3_url} ${data_dir}
fi



if [ "${3}" = "batch" ]; then
    coverage="batch"
else
    coverage="individually"
fi


# If a reference file has not been specified in the app panel, find it
if [ -z ${4} ]; then
    reference=$(get_fasta_file.py --input_dir ../data)
else
    reference=${4}
fi

# If a bed file of regions to exclude has not been specified in the app panel, find it
if [ -z ${5} ]; then
  SVbed=$(find -L ../data/ -name "*.bed")
else
  SVbed=${5}
fi

number_SVbed=$(find -L ../data/ -name "*.bed" | wc -l )
if [ ${number_references} -gt 1 ]; then
  echo "Check your input data: there are multiple .bed files."
  exit 1
fi

# make the path absolute
SVbed=$PWD/${SVbed}


# If an annotation file has not been specified in the app panel, find it
if [ -z ${6} ]; then
    CNVmap=$(find -L ../data/ -name "*blacklist.gz")
else
    CNVmap=${6}
fi

number_CNVmap=$(find -L ../data/ -name "*blacklist.gz" | wc -l )
if [ ${number_CNVmap} -gt 1 ]; then
  echo "Check your input data: there are multiple blacklist.gz files."
  exit 1
fi

# make the path absolute
CNVmap=$PWD/${CNVmap}


if [ -z ${7} ]; then
    svtype=ALL
else
    svtype="${7}"
fi


#Delly primarily parallelizes on the sample level. Hence, OMP_NUM_THREADS should be always smaller or equal to the number of input samples.

if [ -z ${8} ]; then
    num_threads=$(get_cpu_count.py)
else
    num_threads=${8}
fi

num_attached_bams=$(find -L ${data_dir} -name "*.bam" | wc -l)

min=$(( ${num_attached_bams} < ${num_threads} ? ${num_attached_bams} : ${num_threads} ))

export OMP_NUM_THREADS=${min}



## Auxilliary Parameters

## SV discovery options in delly call
if [ -z ${9} ]; then
    min_read_map_quality_discovery=
else
    min_read_map_quality_discovery=--map_qual ${9}
fi


if [ -z ${10} ]; then
    min_split_read_dist=
else
    min_split_read_dist=--minrefsep ${10}
fi


if [ -z ${11} ]; then
    max_split_read_dist=
else
    max_split_read_dist=--maxreadsep ${11}
fi


## SV genotyping options in delly call

if [ -z ${12} ]; then
    min_read_map_quality_genotyping=
else
    min_read_map_quality_genotyping=--geno_qual ${12}
fi


if [ -z ${13} ]; then
    SV_reads_output=
else
    SV_reads_output=--dump ${13}
fi


## merging options 

if [ -z ${14} ]; then
    min_SV_quality=
else
    min_SV_quality=--quality ${14}
fi


if [ -z ${15} ]; then
    min_coverage=
else
    min_coverage=--coverage ${15}
fi


if [ -z ${16} ]; then
    min_SV_size=
else
    min_SV_size=--min_size ${16}
fi


if [ -z ${17} ]; then
    max_SV_size=
else
    max_SV_size=--maxsize ${17}
fi


if [ ${18} == "no" ]; then
    precise_only=
else
    precise_only=--precise
fi



# delly filter options 

if [ -z ${19} ]; then
    min_genotyped_samples=
else
    min_genotyped_samples=--ratiogeno ${19}
fi


# delly CNV options

if [ -z ${20} ]; then
    min_mapping_quality_CNV=
else
    min_mapping_quality_CNV=--quality ${20}
fi


if [ -z ${21} ]; then
    ploidy=
else
    ploidy=--ploidy ${21}
fi


if [ -z ${22} ]; then
    min_CNV_size=
    min_CNV_size2=
else
    min_CNV_size=--cnv-size ${22}
    min_CNV_size2=--minsize ${22}
fi


# read depth window options
if [ -z ${23} ]; then
    window_size=
else
    window_size=--window-size ${23}
fi


if [ -z ${24} ]; then
    window_offset=
else
    window_offset=--window-offset ${24}
fi


if [ -z ${25} ]; then
    bed_intervals=
else
    bed_intervals=--bed-intervals ${25}
fi


if [ -z ${26} ]; then
    min_callable_window_fraction=
else
    min_callable_window_fraction=--fraction-window ${26}
fi


if [ ${27} == "no" ]; then
    mappable_bases_in_window=
else
    mappable_bases_in_window=--adaptive-windowing
fi


# GC fragment normalization options
if [ -z ${28} ]; then
    scan_window_size=
else
    scan_window_size=--scan-windowing ${28}
fi


if [ -z ${29} ]; then
    scanning_regions_in_BED=
else
    scanning_regions_in_BED=--scan-regions ${29}
fi


if [ ${30} == "no" ]; then
    scan_window=
else
    scan_window=--no-window-selection
fi


# Delly classify options

if [ -z ${31} ]; then
    max_CNV_size=
else
    max_CNV_size=--maxsize ${31}
fi


if [ -z ${32} ]; then
    min_site_quality=
else
    min_site_quality=--qual ${32}
fi
