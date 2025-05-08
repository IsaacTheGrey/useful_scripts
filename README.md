# blast_parallel
script to run blastx on a given list of sequences or chunks of sequences against a given database (created with makeblastdb). 
## USAGE
    blastx_parallel.sh [-t N|--test N] [--ramdisk DIR] -i DIR -o DIR -d DB [--top N]

## OPTIONS
    -t, --test N         Run on only the first N chunks (for quick testing)
    --ramdisk DIR        Use DIR (e.g. /dev/shm) to copy DB and chunks for faster I/O
    -i, --input DIR      Directory containing chunked FASTA files (required)
    -o, --output DIR     Directory for BLASTX outputs (required)
    -d, --db DB          BLAST DB basename OR directory containing DB files (required)
    --top N              Keep only top N hits per query (default: 3)
    -h, --help           Show this message and exit
