#!/usr/bin/Rscript
# This script was written by Oliver Pain whilst at King's College London University.
start.time <- Sys.time()
suppressMessages(library("optparse"))

option_list = list(
make_option("--ref_plink_chr", action="store", default=NA, type='character',
		help="Path to per chromosome reference PLINK files [required]"),
make_option("--ref_keep", action="store", default=NA, type='character',
		help="Keep file to subset individuals in reference for clumping [required]"),
make_option("--ref_pop_scale", action="store", default=NA, type='character',
		help="File containing the population code and location of the keep file [required]"),
make_option("--plink", action="store", default='plink', type='character',
		help="Path PLINK software binary [required]"),
make_option("--prsice_path", action="store", default=NA, type='character',
    help="Path to PRSice. [optional]"),
make_option("--rscript", action="store", default='Rscript', type='character',
    help="Path to Rscript [optional]"),
make_option("--output", action="store", default='./Output', type='character',
		help="Path for output files [required]"),
make_option("--memory", action="store", default=5000, type='numeric',
		help="Memory limit [optional]"),
make_option("--sumstats", action="store", default=NA, type='character',
		help="GWAS summary statistics in LDSC format [required]"),
make_option("--covar", action="store", default=NA, type='character',
		help="File containing covariates to be regressed from the scores [optional]"),
make_option("--pTs", action="store", default='1e-8,1e-6,1e-4,1e-2,0.1,0.2,0.3,0.4,0.5,1', type='character',
		help="List of p-value thresholds for scoring [optional]"),
make_option("--dense", action="store", default=F, type='logical',
  help="Specify as T for dense thresholding. pTs then interpretted as seq() command wih default 5e-8,1,5e-4 [optional]"),
make_option("--prune_hla", action="store", default=T, type='logical',
		help="Retain only top assocaited variant in HLA region [optional]")
)

opt = parse_args(OptionParser(option_list=option_list))

library(data.table)

tmp<-sub('.*/','',opt$output)
opt$output_dir<-sub(paste0(tmp,'*.'),'',opt$output)
system(paste0('mkdir -p ',opt$output_dir))

sink(file = paste(opt$output,'.log',sep=''), append = F)
cat(
'#################################################################
# polygenic_score_file_creator_dense.R V1.0
# For questions contact Oliver Pain (oliver.pain@kcl.ac.uk)
#################################################################
Analysis started at',as.character(start.time),'
Options are:\n')

cat('Options are:\n')
print(opt)
cat('Analysis started at',as.character(start.time),'\n')
sink()

#####
# Read in sumstats and insert p-values
#####

sink(file = paste(opt$output,'.log',sep=''), append = T)
cat('Reading in GWAS and harmonising with reference.\n')
sink()

GWAS<-fread(cmd=paste0('zcat ',opt$sumstats))
GWAS<-GWAS[complete.cases(GWAS),]
GWAS$N<-NULL
GWAS$P<-2*pnorm(-abs(GWAS$Z))

sink(file = paste(opt$output,'.log',sep=''), append = T)
cat('GWAS contains',dim(GWAS)[1],'variants.\n')
sink()

GWAS$IUPAC[GWAS$A1 == 'A' & GWAS$A2 =='T' | GWAS$A1 == 'T' & GWAS$A2 =='A']<-'W'
GWAS$IUPAC[GWAS$A1 == 'C' & GWAS$A2 =='G' | GWAS$A1 == 'G' & GWAS$A2 =='C']<-'S'
GWAS$IUPAC[GWAS$A1 == 'A' & GWAS$A2 =='G' | GWAS$A1 == 'G' & GWAS$A2 =='A']<-'R'
GWAS$IUPAC[GWAS$A1 == 'C' & GWAS$A2 =='T' | GWAS$A1 == 'T' & GWAS$A2 =='C']<-'Y'
GWAS$IUPAC[GWAS$A1 == 'G' & GWAS$A2 =='T' | GWAS$A1 == 'T' & GWAS$A2 =='G']<-'K'
GWAS$IUPAC[GWAS$A1 == 'A' & GWAS$A2 =='C' | GWAS$A1 == 'C' & GWAS$A2 =='A']<-'M'

# Extract SNPs that match the reference
GWAS_clean<-NULL
for(i in 1:22){
	bim<-fread(paste0(opt$ref_plink_chr,i,'.bim'))
	
	bim$IUPAC[bim$V5 == 'A' & bim$V6 =='T' | bim$V5 == 'T' & bim$V6 =='A']<-'W'
	bim$IUPAC[bim$V5 == 'C' & bim$V6 =='G' | bim$V5 == 'G' & bim$V6 =='C']<-'S'
	bim$IUPAC[bim$V5 == 'A' & bim$V6 =='G' | bim$V5 == 'G' & bim$V6 =='A']<-'R'
	bim$IUPAC[bim$V5 == 'C' & bim$V6 =='T' | bim$V5 == 'T' & bim$V6 =='C']<-'Y'
	bim$IUPAC[bim$V5 == 'G' & bim$V6 =='T' | bim$V5 == 'T' & bim$V6 =='G']<-'K'
	bim$IUPAC[bim$V5 == 'A' & bim$V6 =='C' | bim$V5 == 'C' & bim$V6 =='A']<-'M'

	bim_GWAS<-merge(bim,GWAS, by.x='V2', by.y='SNP')
	GWAS_clean_temp<-bim_GWAS[bim_GWAS$IUPAC.x == bim_GWAS$IUPAC.y,]
	GWAS_clean<-rbind(GWAS_clean,GWAS_clean_temp)
}

GWAS_clean<-GWAS_clean[,c('V2','A1','A2','Z','P')]
names(GWAS_clean)<-c('SNP','A1','A2','Z','P')

sink(file = paste(opt$output,'.log',sep=''), append = T)
cat('After harmonisation with the reference,',dim(GWAS_clean)[1],'variants remain.\n')
sink()

fwrite(GWAS_clean, paste0(opt$output_dir,'GWAS_sumstats_temp.txt'), sep=' ')

if(opt$prune_hla == T){
	sink(file = paste(opt$output,'.log',sep=''), append = T)
	cat('Extracted top variant in HLA region.\n')
	sink()

	bim<-fread(paste0(opt$ref_plink_chr,'6.bim'))
	bim_GWAS<-merge(bim,GWAS, by.x='V2',by.y='SNP')
	bim_GWAS_hla<-bim_GWAS[bim_GWAS$V4 > 28e6 & bim_GWAS$V4 < 34e6,]
	bim_GWAS_hla_excl<-bim_GWAS_hla[bim_GWAS_hla$P != min(bim_GWAS_hla$P),]
	write.table(bim_GWAS_hla_excl, paste0(opt$output_dir,'hla_exclude.txt'), col.names=F, row.names=F, quote=F)
}

#####
# Clump SNPs in GWAS based on LD in the reference
#####

if(!is.na(opt$ref_keep)){ 
	sink(file = paste(opt$output,'.log',sep=''), append = T)
	cat('Keeping individuals in',opt$ref_keep,'for clumping.\n')
	sink()
} else {
	sink(file = paste(opt$output,'.log',sep=''), append = T)
	cat('Using full reference for clumping.\n')
	sink()
}

sink(file = paste(opt$output,'.log',sep=''), append = T)
cat('Clumping GWAS based on the reference...')
sink()

if(!is.na(opt$ref_keep)){ 
	if(opt$prune_hla == F){
		for(i in 1:22){
			system(paste0(opt$plink,' --bfile ',opt$ref_plink_chr,i,' --keep ',opt$ref_keep,' --clump ',opt$output_dir,'GWAS_sumstats_temp.txt --clump-p1 1 --clump-p2 1 --clump-r2 0.1 --clump-kb 250 --out ',opt$output_dir,'GWAS_sumstats_temp_clumped_chr',i,'.txt --memory ',floor(opt$memory*0.7)))
		}
	} else {
		for(i in 1:22){
			system(paste0(opt$plink,' --bfile ',opt$ref_plink_chr,i,' --keep ',opt$ref_keep,' --exclude ',opt$output_dir,'hla_exclude.txt --clump ',opt$output_dir,'GWAS_sumstats_temp.txt --clump-p1 1 --clump-p2 1 --clump-r2 0.1 --clump-kb 250 --out ',opt$output_dir,'GWAS_sumstats_temp_clumped_chr',i,'.txt --memory ',floor(opt$memory*0.7)))
		}
	}
} else {
	if(opt$prune_hla == F){
		for(i in 1:22){
			system(paste0(opt$plink,' --bfile ',opt$ref_plink_chr,i,' --clump ',opt$output_dir,'GWAS_sumstats_temp.txt --clump-p1 1 --clump-p2 1 --clump-r2 0.1 --clump-kb 250 --out ',opt$output_dir,'GWAS_sumstats_temp_clumped_chr',i,'.txt --memory ',floor(opt$memory*0.7)))
		}
	} else {
		for(i in 1:22){
			system(paste0(opt$plink,' --bfile ',opt$ref_plink_chr,i,' --exclude ',opt$output_dir,'hla_exclude.txt --clump ',opt$output_dir,'GWAS_sumstats_temp.txt --clump-p1 1 --clump-p2 1 --clump-r2 0.1 --clump-kb 250 --out ',opt$output_dir,'GWAS_sumstats_temp_clumped_chr',i,'.txt --memory ',floor(opt$memory*0.7)))
		}
	}
}

GWAS_clumped_all<-NULL
for(i in 1:22){
  clumped<-fread(paste0(opt$output_dir,'GWAS_sumstats_temp_clumped_chr',i,'.txt.clumped'))
  clumped_SNPs<-clumped$SNP
  GWAS_clumped_temp<-GWAS[(GWAS$SNP %in% clumped_SNPs),]
  GWAS_clumped_all<-rbind(GWAS_clumped_all, GWAS_clumped_temp)
}
GWAS_clumped_all$IUPAC<-NULL
names(GWAS_clumped_all)[4]<-'BETA'

write.table(GWAS_clumped_all, paste0(opt$output,'.GWAS_sumstats_clumped.txt'), col.names=T, row.names=F, quote=F)

sink(file = paste(opt$output,'.log',sep=''), append = T)
cat('Done!\n')
sink()

###
# Clean up temporary files
###

system(paste0('rm ',opt$output_dir,'GWAS*'))
if(opt$prune_hla == T){
	system(paste0('rm ',opt$output_dir,'hla_exclude.txt'))
}

####
# Calculate mean and sd of polygenic scores at each threshold
####

# Calculate polygenic scores for reference individuals
sink(file = paste(opt$output,'.log',sep=''), append = T)
cat('Calculating polygenic scores in reference...')
sink()

system(paste0(opt$rscript,' ',opt$prsice,'/PRSice.R --prsice ',opt$prsice,'/PRSice_linux --base ',opt$output,'.GWAS_sumstats_clumped.txt --target ',opt$ref_plink_chr,"# --thread 1 --lower 1e-8 --stat BETA --binary-target F --no-clump --no-regress --out ",opt$output,'ref_score'))

# Read in the scores
scores<-fread(paste0(opt$output,'ref_score.all.score'), header=T)
names(scores)[-1:-2]<-paste0('SCORE_',names(scores)[-1:-2])

sink(file = paste(opt$output,'.log',sep=''), append = T)
cat('Done!\n')
sink()

# Calculate the mean and sd of scores for each population specified in pop_scale
pop_keep_files<-read.table(opt$ref_pop_scale, header=F, stringsAsFactors=F)

for(k in 1:dim(pop_keep_files)[1]){
	pop<-pop_keep_files$V1[k]
	keep<-fread(pop_keep_files$V2[k], header=F)
	scores_keep<-scores[(scores$FID %in% keep$V1),]

	ref_scale<-data.frame(	pT=names(scores_keep[,-1:-2]),
													Mean=round(sapply(scores_keep[,-1:-2], function(x) mean(x)),3),
													SD=round(sapply(scores_keep[,-1:-2], function(x) sd(x)),3))

	fwrite(ref_scale, paste0(opt$output,'.',pop,'.scale'), sep=' ')
}

###
# Clean up temporary files
###

system(paste0('rm ',opt$output,'ref_score.all.score'))

end.time <- Sys.time()
time.taken <- end.time - start.time
sink(file = paste(opt$output,'.log',sep=''), append = T)
cat('Analysis finished at',as.character(end.time),'\n')
cat('Analysis duration was',as.character(round(time.taken,2)),attr(time.taken, 'units'),'\n')
sink()
