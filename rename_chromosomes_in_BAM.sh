# This script is meant to rename the chromosomal contigs in a BAM file in case they do not match a genome they need to be mapped to. To be run, it needs a translation table in a tsv format BAM -> fasta_genome
#!/bin/bash
MAPFILE=/home/federico/projects/mm39/mm39_map.tsv  #modify this according to your translation table



for bam in *.bam; do
    echo "Processing $bam ..."
    samtools view -h "$bam" \
    | awk -v mapfile=$MAPFILE '
        BEGIN {
            FS=OFS="\t"   # use tabs for splitting & output
            while ((getline < mapfile) > 0) {
                old2new[$1] = $2
            }
        }
        /^@SQ/ {
            for (i=1; i<=NF; i++) {
                if ($i ~ /^SN:/) {
                    old = substr($i,4)
                    if (old in old2new) {
                        $i = "SN:" old2new[old]
                    }
                }
            }
            print; next
        }
        /^@/ { print; next }
        {
            if ($3 in old2new) {
                $3 = old2new[$3]
            }
            print
        }
    ' \
    | samtools view -b -o "${bam%.bam}.renamed.bam" -

    samtools sort -o "${bam%.bam}.renamed.sorted.bam" "${bam%.bam}.renamed.bam"
    samtools index "${bam%.bam}.renamed.sorted.bam"
    rm "${bam%.bam}.renamed.bam"
done

