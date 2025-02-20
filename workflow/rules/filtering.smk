rule select_calls:
    input:
        ref="resources/genome.fasta",
        fai="resources/genome.fasta.fai",
        dict="resources/genome.dict",
        vcf="results/genotyped/all.vcf.gz",
        tbi="results/genotyped/all.vcf.gz.tbi",
    output:
        vcf=temp("results/filtered/all.{vartype}.vcf.gz"),
        tbi=temp("results/filtered/all.{vartype}.vcf.gz.tbi"),
    params:
        extra=get_vartype_arg,
    log:
        "logs/gatk/selectvariants/{vartype}.log",
    wrapper:
        "v1.29.0/bio/gatk/selectvariants"


rule hard_filter_calls:
    input:
        ref="resources/genome.fasta",
        fai="resources/genome.fasta.fai",
        dict="resources/genome.dict",
        vcf="results/filtered/all.{vartype}.vcf.gz",
        tbi="results/filtered/all.{vartype}.vcf.gz.tbi",
    output:
        vcf=temp("results/filtered/all.{vartype}.hardfiltered.vcf.gz"),
    params:
        filters=get_filter,
    log:
        "logs/gatk/variantfiltration/{vartype}.log",
    wrapper:
        "v1.29.0/bio/gatk/variantfiltration"


rule recalibrate_calls:
    input:
        vcf="results/filtered/all.{vartype}.vcf.gz",
    output:
        vcf=temp("results/filtered/all.{vartype}.recalibrated.vcf.gz"),
    params:
        extra=config["params"]["gatk"]["VariantRecalibrator"],
    log:
        "logs/gatk/variantrecalibrator/{vartype}.log",
    wrapper:
        "v1.29.0/bio/gatk/variantrecalibrator"


rule merge_calls:
    input:
        vcfs=expand(
            "results/filtered/all.{vartype}.{filtertype}.vcf.gz",
            vartype=["snvs", "indels"],
            filtertype="recalibrated"
            if config["filtering"]["vqsr"]
            else "hardfiltered",
        ),
    output:
        vcf="results/filtered/all.vcf.gz",
    log:
        "logs/picard/merge-filtered.log",
    wrapper:
        "v1.29.0/bio/picard/mergevcfs"
