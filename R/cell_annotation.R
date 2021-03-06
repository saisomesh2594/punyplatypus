#' Cell type guess
#' This function is a R adaptation from Alona similar python function. It uses PanglaoDB database
#' @param markers Dataframe with seurat marker predictions.
#' @param species use mouse or human (default: "mouse")
#' @param pvalue maximum pvalue for significancy on fisher test (default: 0.05)
#' @keywords single-cell celltype
#' @export
#' @import dplyr
#' @return A list containing celltype predictions with adjusted p-values (fdr) and many other measures of performance. Output table is sorted by cluster and PPV (precision) as this one was the best classifier in some benchmarking datasets.
#' @examples
#' celltypes(markers, species = "mouse", pvalue = 0.01)


#TODO :
# Make p-value a parameter
# remove the dplyr library call from here
#

#library(dplyr)

cellType <- function(markers, species="mouse", pvalue=0.05){
  #markers<-markers[, c(2,6,7)]
  markers$gene<-toupper(markers$gene)
  split_list<- split(markers,markers$cluster)
  all_genes_dataset<-unique(markers$gene)
  markerSet<-markersSet(species=species)
  markerSet_freq<-table(markerSet$official.gene.symbol)
  weights = as.data.frame(1+sqrt(((max(markerSet_freq)-markerSet_freq)/(max(markerSet_freq)-min(markerSet_freq)))))


  split_list_marker<- split(markerSet,markerSet$cell.type)
  all_genes_markers<-as.character(unique(markerSet$official.gene.symbol))

  #Fix this matrix initiation:
  output<-c("", "", 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1)
  output<-as.data.frame(output)
  colnames(output)<-"NA"
  rownames(output)<-c("cluster", "celltype", "pvalue", "TPR", "TNR", "PPV", "NVP", "FNR",
                      "FPR", "FDR", "FOR", "TS", "ACC", "F1")

  for (i in 1:length(split_list)){
    #results=NA
    #names(results)<-"None"
    cluster<-as.data.frame(split_list[[i]])
    cluster<-merge(cluster, weights[weights$Var1 %in% cluster$gene,], by.x="gene", by.y="Var1")
    for (j in 1:length(split_list_marker)){
      markers_cellT<-as.data.frame(split_list_marker[[j]])
      markers_cellT<-merge(markers_cellT, weights[weights$Var1 %in% markers_cellT$official.gene.symbol,], by.x="official.gene.symbol", by.y="Var1")
      #how many expressed genesets are found in the geneset?
      ct_exp<-(intersect(cluster$gene,markers_cellT$official.gene.symbol))
      # how many _non_ expressed genes are found in the geneset?
      diff_gene_dataset<-setdiff(all_genes_dataset, ct_exp)
      ct_non_exp<-(intersect(diff_gene_dataset,markers_cellT$official.gene.symbol))
      # how many expressed genes are NOT found in the geneset?
      ct_exp_not_found<-setdiff(cluster$gene,markers_cellT$official.gene.symbol)
      # how many _non_ expressed genes are NOT found in the geneset?
      not_exp_not_found_in_geneset<-(setdiff(diff_gene_dataset, markers_cellT$official.gene.symbol))
      # how many expressed genes are found in the whole markerSet?
      exp_others<-(intersect(diff_gene_dataset,all_genes_markers))
      # how many from the category did not find in the dataset
      TP<-length(ct_exp)
      TN<-length(all_genes_markers)-length(markers_cellT$official.gene.symbol)
      FP<-length(cluster$gene)-length(ct_exp)
      FN<-length(setdiff(markers_cellT$official.gene.symbol, cluster$gene))###
      odds<-fisher.test(matrix(c(length(ct_exp), length(ct_non_exp), length(ct_exp_not_found), length(not_exp_not_found_in_geneset)),  nrow = 2))
      odds$p.value<-p.adjust(odds$p.value, method = "fdr")
      if(odds$p.value<=pvalue){ #Make this a parameter

        overl<-length(ct_exp)
        overl_others<-length(ct_non_exp)
        non_overl<-length(ct_exp_not_found)
        non_overl_others<-length(not_exp_not_found_in_geneset)
        exp_other_total<-length(exp_others)

        TPR<-TP/(TP+FN)
        TNR<-TN/(TN+FP)
        PPV<-TP/(TP+FP)
        NVP<-TN/(TN+FN)
        FNR<-1-TPR
        FPR<-1-TNR
        FDR<-1-PPV
        FOR<-1-NVP
        TS<-TP/(TP+FN+FP)

        ACC <- (TP+TN)/(TP+TN+FP+FN)
        F1  <- 2*TP/(2*TP+(FP+FN))
        #specificity <- (overl+1) / (exp_other_total+1)
        fish<-odds$p.value
        results<-c(unique(as.character(cluster$cluster)), unique(as.character(markers_cellT$cell.type)), fish, TPR, TNR, PPV, NVP, FNR,
                   FPR, FDR, FOR, TS, ACC, F1)
        results<-as.data.frame(results)
        rownames(results)<-c("cluster", "celltype", "pvalue", "TPR", "TNR", "PPV", "NVP", "FNR",
                             "FPR", "FDR", "FOR", "TS", "ACC", "F1")
        colnames(results)<-j
        output<-cbind(output, results)
      }
    }
    #print(unique(as.character(cluster$cluster)))
  }
  output<-output[,2:ncol(output)]
  output<-t(output)
  output<-as.data.frame(output)
  output$pvalue<-as.numeric(gsub(",", ".", as.character(output$pvalue)))
  output$PPV<-as.numeric(gsub(",", ".", as.character(output$PPV)))
  #output$F1<-as.numeric(gsub(",", ".", as.character(output$F1)))
  output<-output[order(output$cluster, -output$PPV),]
  rownames(output)<-NULL
  return(output)
}


markersSet <- function(species="mouse"){
  ma<-read.csv(system.file("data", "markers.tsv", package = "punyplatypus"), sep="\t")
  #ma<-read.csv("~/Dropbox/GIT/RCodes/punyplatypus/data/dataset_test.txt", sep="\t")
  if (species == 'mouse'){
    s = 'Mm'
  }else if (species == 'athaliana'){
    s = 'At'
  } else{
    s = 'Hs'
  }
  ma<-ma[grepl(s, ma$species),]
  ma<-ma[ma$ubiquitousness.index<0.05,]
  ma_ss<-ma[,2:3]
  return(ma_ss)
}

