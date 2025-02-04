#!/usr/bin/bash
set -ex

source ./config.sh

attached_bams=$(find -L ${data_dir} -name "*.bam")

mkdir -p ../results/dellySV/1calls/
mkdir -p ../results/dellySV/2mergelist/
mkdir -p ../results/dellySV/3geno/
mkdir -p ../results/dellySV/4merge/
mkdir -p ../results/dellySV/5filter/

mkdir -p ../results/dellyCNV/1CNVcall/
mkdir -p ../results/dellyCNV/2merge/
mkdir -p ../results/dellyCNV/3CNV/
mkdir -p ../results/dellyCNV/4merge/
mkdir -p ../results/dellyCNV/5filter/
mkdir -p ../results/dellyCNV/6plot/



# If coverage is low, samples should be processed together
if [ "${coverage}" = "batch" ]; then
    # 1. In batches for low coverage genomes, use Split-read and Paired-end methods to discover SVs
    /delly/src/delly call -t ${svtype} -g ${reference} -x ${SVbed} ${min_read_map_quality_discovery} ${min_split_read_dist} ${max_split_read_dist} -o ../results/dellySV/1calls/batch_dellySV.vcf ${attached_bams}
    
# if coverage is high, samples should be processed one-by-one
elif [ "${coverage}" = "individually" ]; then 
    # 1. for each sample file, use Split-read and Paired-end methods to discover SVs
    for bam in ${attached_bams}; do
        /delly/src/delly call -t ${svtype} -g ${reference} -x ${SVbed} ${min_read_map_quality_discovery} ${min_split_read_dist} ${max_split_read_dist} -o ../results/dellySV/1calls/$(basename ${bam} .bam)_dellySV.vcf ${bam} 
    done
fi

# 2. Merge SV sites into a unified site list
/delly/src/delly merge -o ../results/dellySV/2mergelist/mergedSVdelly.bcf ${min_SV_quality} ${min_coverage} ${min_SV_size} ${max_SV_size} ${precise_only} $(find -L ../results/dellySV/1calls/ -name "*_dellySV.vcf")

# 3. Genotype this merged SV site list across all samples.
for bam in ${attached_bams}; do
    /delly/src/delly call -t ${svtype} -g ${reference} -x ${SVbed} ${min_read_map_quality_genotyping} ${SV_reads_output} -v ../results/dellySV/2mergelist/mergedSVdelly.bcf -o ../results/dellySV/3geno/$(basename ${bam} .bam)_dellySV.vcf ${bam}
done

# 4. Merge all genotyped samples to get a single BCF using bcftools merge, then index
bcftools merge -m id -O b -o ../results/dellySV/4merge/merged.bcf $(find -L ../results/dellySV/3geno -name "*.vcf") --threads ${num_threads} --force-samples
bcftools index -c --threads ${num_threads} ../results/dellySV/4merge/merged.bcf


if [ ${num_attached_bams} -gt 20 ]; then
# 5. Apply the germline SV filter which requires at least 20 unrelated samples
    /delly/src/delly filter -f germline ${min_SV_quality} ${min_SV_size} ${max_SV_size} ${min_genotyped_samples} -o ../results/dellySV/5filter/germline.bcf ../results/dellySV/4merge/merged.bcf


    # 1. Call CNVs for each sample and refine breakpoints using delly SV calls
    for bam in ${attached_bams}; do
        /delly/src/delly cnv -g ${reference} -m ${CNVmap} -l ../results/dellySV/5filter/germline.bcf ${min_mapping_quality_CNV} ${ploidy} ${min_CNV_size} ${window_size} ${window_offset} ${bed_intervals} ${min_callable_window_fraction} ${mappable_bases_in_window} ${scan_window_size} ${scanning_regions_in_BED} ${scan_window} -o ../results/dellyCNV/1CNVcall/$(basename ${bam} .bam)_dellyCNV.bcf ${bam}
    done

else

    # 1. Alternately, call CNVs but do not refine breakpoints using delly SV calls because there are not enough samples.
    for bam in ${attached_bams}; do
        /delly/src/delly cnv -g ${reference} -m ${CNVmap} ${min_mapping_quality_CNV} ${ploidy} ${min_CNV_size} ${window_size} ${window_offset} ${bed_intervals} ${min_callable_window_fraction} ${mappable_bases_in_window} ${scan_window_size} ${scanning_regions_in_BED} ${scan_window} -o ../results/dellyCNV/1CNVcall/$(basename ${bam} .bam)_dellyCNV.bcf ${bam}
    done

fi


# 2. Merge CNVs into a unified site list
/delly/src/delly merge -e -p ${min_SV_quality} ${min_coverage} ${min_SV_size} ${max_SV_size} ${precise_only} ${max_breakpoint_offset} -o ../results/dellyCNV/2merge/dellyCNV.vcf ../results/dellyCNV/1CNVcall/*.bcf


# 3. Genotype CNVs for each sample, with copy number segmentation.
for bam in ${attached_bams}; do
    /delly/src/delly cnv -u -v ../results/dellyCNV/2merge/dellyCNV.vcf -g ${reference} -m ${CNVmap} ${min_mapping_quality_CNV} ${ploidy} ${min_CNV_size} ${window_size} ${window_offset} ${bed_intervals} ${min_callable_window_fraction} ${mappable_bases_in_window} ${scan_window_size} ${scanning_regions_in_BED} ${scan_window} -o ../results/dellyCNV/3CNV/$(basename ${bam} .bam).bcf -c ../results/dellyCNV/3CNV/$(basename ${bam} .bam)_out.cov.gz ${bam}
done

# 4. Merge all genotyped samples to get a single BCF using bcftools merge, then index
bcftools merge -m id -O b --threads ${num_threads} -o ../results/dellyCNV/4merge/merged.bcf $(find ../results/dellyCNV/3CNV/ -name "*.bcf") --force-samples
bcftools index -c --threads ${num_threads} ../results/dellyCNV/4merge/merged.bcf

# 5. Filter for germline CNVs
/delly/src/delly classify -f germline ${min_CNV_size2} ${max_CNV_size} ${ploidy} ${min_site_quality} -o ../results/dellyCNV/5filter/filtered.bcf ../results/dellyCNV/4merge/merged.bcf



## Plotting CNVs

if [ ${num_attached_bams} -gt 100 ]
then
    # Plot copy-number distribution for large number of samples (>>100)
    bcftools query -f "%ID[\t%RDCN]\n" ../results/dellyCNV/5filter/filtered.bcf > ../results/dellyCNV/6plot/plot.tsv

    # change directory so that we can see output, printed to pwd, without editing the plotting script
    # this saves a separate plot for each CNV that is a histogram of how many samples have each number of CNV
    cd ../results/dellyCNV/6plot
    R CMD BATCH "--args plot.tsv" /delly/R/cnv.R
    cd ../../../code
fi


# Plot segmented read depth profiles
# Convert from VCF to BED. 
for bcffiles in $(find -L ../results/dellyCNV/3CNV/ -name "*.bcf"); do
    bcftools query -f "%CHROM\t%POS\t%INFO/END\t%ID\t[%RDCN]\n" ${bcffiles} > ../results/dellyCNV/6plot/$(basename ${bcffiles} .bcf)_segmentation.bed
done 

# For each sample, get the name prefix, create a new directory to put plots, navigate into that directory so R plots are saved in a writable location, run the R script to make plots, and change back to /code/ directory. 
for samplename in ${attached_bams}; do
    prefix=$(basename ${samplename} .bam)
    mkdir -p ../results/dellyCNV/6plot/${prefix}_plots_seg
    cd ../results/dellyCNV/6plot/${prefix}_plots_seg
    R CMD BATCH "--args ../../3CNV/${prefix}_out.cov.gz ../${prefix}_segmentation.bed" /delly/R/rd.R 
    cd
done

#delete tempfiles if we downloaded from s3. 
if [ ! -z ${s3_url} ]; then
    rm -rf ${data_dir}
fi
