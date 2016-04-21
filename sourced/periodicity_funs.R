#!/usr/bin/env Rscript

## Imports ####################################################################

library(IRanges)
library(parallel)

SOURCE.DIR <- "/home/rilla/nucleServ/rcode/sourced"
source(paste(SOURCE.DIR,
             "helperfuns.R",
             sep="/"))

###############################################################################

findFirstAndLast <- function(id, start, end, strand, dyads, chr)
{
    in.gene <- dyads[dyads >= start & dyads <= end]
    if (strand == "-") {
        in.gene <- rev(in.gene)
    }
    if (length(in.gene)) {
        data.frame(afdsafdahikd     = id,
                   chrom  = chr,
                   strand = strand,
                   start  = start,
                   end    = end,
                   first  = in.gene[1],
                   last   = in.gene[length(in.gene)])
    } else {
        NULL
    }
}


data.frame(foo = id,
           chrom  = chr,
           strand = strand,
           start  = start,
           end    = end,
           first  = in.gene[1],
           last   = in.gene[length(in.gene)])




ecov <- function (x, period)
    (1 + sin(pi/2 + 2*pi/period*x)) * 0.8^(abs(x)/period)

# Create a coverage for a gene given p1.pos and last.pos and their periodicity
coverageChr <- function(nuc.start, nuc.end, nuc.length, strand, L, period)
{
    revIt <- function(xs)
        rev(xs) * (-1)

    cov <- rep(0, L)

    for (i in seq_along(nuc.start)) {
        sper <- floor(period/2)
        xs <- (-sper):(period*floor(nuc.length[i]/period) + sper)

        if (strand[i] == "+") {
            a <- xs
            b <- revIt(xs)
        } else if (strand[i] == "-") {
            a <- revIt(xs)
            b <- xs
        }

        x <- nuc.start[i] + a
        y <- nuc.end[i] + b

        cov[round(x)] <- cov[round(x)] + ecov(a, period)
        cov[round(y)] <- cov[round(y)] + ecov(b, period)
    }

    cov
}

findGenesNucs <- function (genes, calls, mc.cores=1)
{
    chroms <- unique(genes$chrom)
    genes.by.chr <- lapply(chroms,
                           function (chr) subset(genes, chrom == chr))
    names(genes.by.chr) <- chroms
    dyads.by.chr <- lapply(ranges(calls), dyadPos)

    used.cols <- c("ID", "start", "end", "strand")

    genes.nucs <- do.call(rbind, xlapply(
        chroms,
        function(chr) {
            vals <- iterDf(genes.by.chr[[chr]][, used.cols],
                           findFirstAndLast,
                           dyads.by.chr[[chr]],
                           chr)
            filtered <- vals[!sapply(vals, is.null)]
            do.call(rbind, filtered)
        },
        mc.cores=mc.cores
    ))

    genes.nucs$nuc.length <- abs(genes.nucs$last - genes.nucs$first)

    genes.nucs
}

getPeriodCov <- function (genes.nucs, period, mc.cores=1)
{
    chroms <- unique(genes.nucs$chrom)

    chr.lens <- sapply(
        chroms,
        function(chr)
            max(genes.nucs[genes.nucs$chrom == chr, "end"]) + 500
    )
    names(chr.lens) <- chroms

    cov <- xlapply(
        chroms,
        function (chr)
            do.call(coverageChr,
                    c(unname(as.list(subset(genes.nucs,
                                            subset=chrom == chr,
                                            select=c("first",
                                                     "last",
                                                     "nuc.length",
                                                     "strand")))),
                      chr.lens[[chr]] + 500,
                      period)),
        mc.cores=mc.cores
    )
    names(cov) <- chroms
    cov
}