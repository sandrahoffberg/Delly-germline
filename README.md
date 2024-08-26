[![Code Ocean Logo](images/CO_logo_135x72.png)](http://codeocean.com/product)

<hr>

# Germline structural variant & CNV calling in Delly

This capsule does Structural Variant calling based on paired-end and split-reads and Copy Number Variation calling based on read depth in (Illumina) short reads only.

Delly is an integrated structural variant (SV) prediction method that can discover, genotype and visualize deletions, tandem duplications, inversions and translocations at single-nucleotide resolution in short-read and long-read massively parallel sequencing data. It uses paired-ends, split-reads and read-depth to sensitively and accurately delineate genomic rearrangements throughout the genome.  

See the [Delly Github](https://github.com/dellytools/delly) for more information. 


## Input 
**Bam Files**
- BAM file that has been trimmed, aligned to reference, sorted, duplicate marked, read groups adjusted if necessary, indexed.  This capsule downloads data from an S3 bucket if a URL is provided in the App Panel. If no URL is provided, it will search for bam files in the **/data** directory.  It can use sample data from both locations in the same run. 

**Genome Fasta**
- In the **/data** directory, a genome in fasta format (```.fa``` ending) with an index created in Samtools that ends in ```.fa.fai```  is required to identify split-reads

**Mappability Map**
- Optional: mappability map, [downloaded here](https://gear.embl.de/data/delly/).    A ```fasta``` format file with repetitive regions of the genome hardmasked, ending in ```.blacklist.gz``` and both an ```.fai``` and ```.gzi``` index in the **/data** directory.

**Repetitive Regions BED**
- Optional: a BED file of repetitive regions to exclude (e.g., telomeres and centromeres) located in the **/data** directory.  The contig/scaffold name in the first column, start position in the second column, and end position in the third column.  The one used here was downloaded from [SpeedSeq Github page](https://github.com/hall-lab/speedseq/blob/master/annotations/exclude.cnvnator_100bp.GRCh38.20170403.bed) and linked to from smoove Github page.


## Outputs
- A folder for SV calling entitled ```/results/dellySV/``` containing
    - A subfolder ```/1calls``` containing SV calls for each sample, saved in a VCF with an index
    - A subfolder ```/2mergelist``` containing a bcf file with SV calls for each sample merged, called ```mergedSVdelly.bcf``` with an index
    - A subfolder ```/3geno``` containing more accurate SV genotypes for each sample, saved in a VCF with an index
    - A subfolder ```/4merge``` containing a bcf file with SV genotypes for each sample merged called ```merged.bcf``` with an index
    - If more than 20 samples present, a subfolder ```/5filter``` containing a filtered bcf file of the merged SV genotypes, called ```germline.bcf``` with an index
- A folder for CNV calling entitled ```/results/dellyCNV/``` containing
    - A subfolder ```/1CNVcall``` containing CNV calls for each sample, saved as a BCF with an index
    - A subfolder ```/2merge``` containing a vcf file with CNV calls for each sample merged, called ```dellyCNV.vcf``` with an index
    - A subfolder ```/3CNV``` containing more accurate CNV genotypes for each sample, saved in a BCF with an index.  In addition, a ```_out.cov.gz``` file is saved for each sample to plot the read depth and copy number segmentation. 
    - A subfolder ```/4merge``` containing a bcf file with SV genotypes for each sample merged called ```merged.bcf``` with an index
    - A subfolder ```/5filter``` containing a filtered bcf file of the merged SV genotypes, called ```filtered.bcf``` with an index
    - A subfolder ```/6plot``` containing 2 types of plots: 
        - If more than 100 samples present: a separate plot for each CNV is produced that show a histogram of how many samples have each number of copies.
        - Copy number segmentation.  A plot is made of the read depth of each chromosome and the entire genome for each sample. Copy number segmentation (after read number normalization) is laid on top of this to visualize the location of CNVs. 


## App Panel Parameters

### Main Parameters
- The URL of the S3 bucket with ```bam``` files, if they are not in the **/data** directory of this capsule. 
- The location to downolad the ```bam``` files from S3 [Default: /results/data]
- Whether to process samples individually or in batch for SV calling. Processing individually is better for high coverage samples, while processing in batch provides more power to detect variants for low coverage samples.  
- Path to the genome reference
- Path to the bed file of regions to exclude
- Path to the genome annotation file 
- The type of Structural Variants to detect: DELetions, INSertions, DUPlications, INVersions, BreakeND, or ALL types. [Default: ALL]
- Number of threads to run on. Delly primarily parallelizes on the sample level. Hence, OMP_NUM_THREADS should be always smaller or equal to the number of input samples. [Default: 1]

### Auxilliary Parameters

- Minimum MAPQ quality for paired end mapping during SV discovery.  This is an integer value ranging from 0 to 255 and the optimal value can depend on the aligner used.  When in doubt, the user can plot the MAPQ distribution in a BAM file [Default: 1]
- Minimum distance on a reference for how far apart split-reads need to be [Default: 25 bp]
- Maximum distance on a reference for how far apart split-reads can be [Default: 40 bp]
- Minimum MAPQ quality for paired end mapping during SV genotyping. This is an integer value ranging from 0 to 255 and the optimal value can depend on the aligner used.  When in doubt, the user can plot the MAPQ distribution in a BAM file [Default: 5]
- gzipped output file for SV-reads
- Minimum SV site quality for merging [Default: 300]
- Minimum coverage for merging [Default: 10]
- Minimum SV length [Default: 0 bp]
- Maximum SV length [Default: 1,000,000 bp for merging; 500,000,000 bp for filtering]
- Only retain SVs with Precise tag during merging? This should only be used with whole exon data, not whole genome data [Default: no]
- Minimum fraction of genotyped samples for filtering [Default: 0.75]
- Minimum mapping quality for CNVs [Default: 10]
- Ploidy [Default: 2]
- Minimum CNV size [Default: 1000]
- Window size for read-depth windows [Default: 10,000]
- Window offset for read-depth windows [Default: 10,000]
- Input BED file with the windows for read-depth windows
- Minimum fraction of the window that is callable for read-depth windows [Default: 0.25]
- Use mappable bases for window size? [Default: no]
- Scanning window size for GC fragment normalization [Default: 10,000]
- Scanning regions in BED format for GC fragment normalization
- Scan window selection for GC fragment normalization [Default: no]
- Maximum CNV size [Default: 500,000,000]
- Minimum site quality of CNVs (Phred-scaled quality score for the variant) for filtering with delly classify [Default: 50]

## Source

https://github.com/dellytools/delly

## Cite

Tobias Rausch, Thomas Zichner, Andreas Schlattl, Adrian M. Stuetz, Vladimir Benes, Jan O. Korbel.
DELLY: structural variant discovery by integrated paired-end and split-read analysis.
Bioinformatics. 2012 Sep 15;28(18):i333-i339.
https://doi.org/10.1093/bioinformatics/bts378

<hr>

[Code Ocean](https://codeocean.com/) is a cloud-based computational platform that aims to make it easy for researchers to share, discover, and run code.<br /><br />
[![Code Ocean Logo](images/CO_logo_68x36.png)](https://www.codeocean.com)