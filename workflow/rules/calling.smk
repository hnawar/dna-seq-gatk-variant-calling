if "restrict-regions" in config["processing"]:

    rule compose_regions:
        input:
            config["processing"]["restrict-regions"],
        output:
            "results/called/{contig}.regions.bed",
        conda:
            "../envs/bedops.yaml"
        shell:
            "bedextract {wildcards.contig} {input} > {output}"


rule call_variants:
    input:
        bam=get_sample_bams,
        bai=get_sample_bais,
        ref="resources/genome.fasta",
        fai="resources/genome.fasta.fai",
        idx="resources/genome.dict",
        known="resources/variation.noiupac.vcf.gz",
        tbi="resources/variation.noiupac.vcf.gz.tbi",
        regions=(
            "results/called/{contig}.regions.bed"
            if config["processing"].get("restrict-regions")
            else []
        ),
    output:
        gvcf=protected("results/called/{sample}.{contig}.g.vcf.gz"),
        tbi=protected("results/called/{sample}.{contig}.g.vcf.gz.tbi"),
    log:
        "logs/gatk/haplotypecaller/{sample}.{contig}.log",
    params:
        extra=" --create-output-variant-index ",
    wrapper:
        "v1.29.0/bio/gatk/haplotypecaller"


rule combine_calls:
    input:
        ref="resources/genome.fasta",
        fai="resources/genome.fasta.fai",
        dict="resources/genome.dict",
        gvcfs=expand(
            "results/called/{sample}.{{contig}}.g.vcf.gz", sample=samples.index
        ),
        tbis=expand(
            "results/called/{sample}.{{contig}}.g.vcf.gz.tbi", sample=samples.index
        ),
    output:
        gvcf="results/called/all.{contig}.g.vcf.gz",
        tbi="results/called/all.{contig}.g.vcf.gz.tbi",
    log:
        "logs/gatk/combinegvcfs.{contig}.log",
    params:
        extra=" --create-output-variant-index ",
    wrapper:
        "v1.29.0/bio/gatk/combinegvcfs"


rule genotype_variants:
    input:
        ref="resources/genome.fasta",
        fai="resources/genome.fasta.fai",
        dict="resources/genome.dict",
        gvcf="results/called/all.{contig}.g.vcf.gz",
        tbi="results/called/all.{contig}.g.vcf.gz.tbi",
    output:
        vcf=temp("results/genotyped/all.{contig}.vcf.gz"),
    params:
        extra=config["params"]["gatk"]["GenotypeGVCFs"],
    log:
        "logs/gatk/genotypegvcfs.{contig}.log",
    wrapper:
        "v1.29.0/bio/gatk/genotypegvcfs"


rule merge_variants:
    input:
        vcfs=lambda w: expand(
            "results/genotyped/all.{contig}.vcf.gz", contig=get_contigs()
        ),
    output:
        vcf="results/genotyped/all.vcf.gz",
        tbi="results/genotyped/all.vcf.gz.tbi",
    log:
        "logs/picard/merge-genotyped.log",
    wrapper:
        "v1.29.0/bio/picard/mergevcfs"
