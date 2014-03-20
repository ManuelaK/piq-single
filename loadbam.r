#assert existence of
#commonfile
source(commonfile)
#bamfile
load(bamfile)
#pwmfile
load(paste0(pwmdir,pwmid,'.pwmout.RData'))
#tmpdir

coords2=sapply(coords.short,flank,width=wsize,both=T)

obschrnames=names(allreads)
preads=allreads[[obschrnames[1]]]$plus
cutat=sort(rle(preads)$lengths,T)[200]

#stablize the variance (helps when there are few high coverage sites).
tfun <- function(x){
    y = x
    x[x>cutat]=cutat
    y[x>0] = sqrt(x[x>0])
    y
}

unlink(paste0(tmpdir,'*tf',pwmid,'*'))

use.w=!is.null(whitelist)
if(use.w){
    wtable=read.table(whitelist)
    white.list=lapply(levels(wtable[,1]),function(i){
        wtchr=wtable[wtable[,1]==i,]
        ir=IRanges(wtchr[,2],wtchr[,3])
    })
    names(white.list)=levels(wtable[,1])
}

makeTFmatrix <- function(coords,prefix='',offset=0){
    cwidth = width(coords[[1]][1])
    obschrnames=names(allreads)
    validchr = obschrnames[which(obschrnames%in%ncoords)]
    if(use.w){
        validchr= validchr[validchr%in%names(white.list)]
        coords=lapply(validchr,function(i){
            pwmhits=coords[[i]]
            white.list.chr=white.list[[i]]
            fos=findOverlaps(pwmhits,white.list.chr,type='within')
            pwmhits[queryHits(fos)]
        });names(coords)=validchr
        validchr=validchr[sapply(coords,length)>0]
    }
    readcov=sapply(validchr,function(i){length(allreads[[i]]$plus)+length(allreads[[i]]$minus)})/seqlengths(genome)[validchr]
    readfact = readcov/readcov[1]
    slen = seqlengths(genome)
    scrd =sapply(coords,length)
    minbgs=floor(max(10000,sum(scrd))*(scrd/sum(scrd)));
    for(chr in validchr){
        chrlen = slen[chr]
        print(chr)
        if(prefix=='background.'){
            nsites = max(length(coords[[chr]]),minbgs[chr])
            #coind = sample(1:(chrlen),nsites,replace=T)
            coind = sample(start(coords[[chr]]),nsites,replace=T)+offset
            if(use.w){
                wchr=white.list[[chr]]
                wlarge=wchr[width(wchr)>(2*wsize+1)]
                csamp = sample(1:length(wlarge),nsites,prob=(width(wlarge)-(2*wsize)),replace=T)
                starts = start(wlarge)[csamp]
                ends = end(wlarge)[csamp]
                coind=do.call(c,lapply(1:length(csamp),function(i){
                    sample((starts[i]+wsize):(ends[i]-wsize),1)
                }))
            }
            chrcoord=sort(IRanges(start=coind-wsize,width=2*wsize))
        }else{
            chrcoord=coords[[chr]]
        }
	pluscoord=allreads[[chr]]$plus
	minuscoord=allreads[[chr]]$minus
        if(length(pluscoord)>0){
            rre = rle(sort(pluscoord))
            irp=IRanges(start=rre$values,width=1)
            fos=findOverlaps(chrcoord,irp)
            uquery=queryHits(fos)
            querycoord=rre$values[subjectHits(fos)]
            uoffset = querycoord-start(chrcoord)[uquery]+1
            rval= rre$lengths[subjectHits(fos)] / readfact[chr]
            pos.triple = cbind(round(uquery),round(uoffset),tfun(rval))
            pos.mat=sparseMatrix(i=round(uoffset),j=round(uquery),x=tfun(rval),dims=c(2*wsize,length(chrcoord)),giveCsparse=T)
        }else{
            pos.triple=cbind(1,1,0)
            pos.mat=Matrix(0,nrow=2*wsize,ncol=length(chrcoord))
        }
    #
        if(length(minuscoord)>0){
            rre = rle(sort(minuscoord))
            irp=IRanges(start=rre$values,width=1)
            fos=findOverlaps(chrcoord,irp)
            uquery=queryHits(fos)
            querycoord=rre$values[subjectHits(fos)]
            uoffset = querycoord-start(chrcoord)[uquery]+1
            rval= rre$lengths[subjectHits(fos)] / readfact[chr]
            neg.triple = cbind(round(uquery),round(uoffset),tfun(rval))
            neg.mat=sparseMatrix(i=round(uoffset),j=round(uquery),x=tfun(rval),dims=c(2*wsize,length(chrcoord)),giveCsparse=T)
        }else{
            neg.triple=cbind(1,1,0)
            neg.mat=Matrix(0,nrow=2*wsize,ncol=length(chrcoord))
        }
#
        save(pos.mat,neg.mat,pos.triple,neg.triple,file=paste0(tmpdir,prefix,'tf',pwmid,'-',chr,'.RData'))
	gc()
    }
}

makeTFmatrix(coords2,'positive.')
makeTFmatrix(coords2,'background.',10000)

#
#####
