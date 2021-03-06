##################################################
## Name: 006_prediction  
## Script purpose: Predicting LD peaks and troughs with environmental information using Random Forest classification
## Date: 2018
## Author: Curdin Derungs
##################################################

library(ggplot2)
library(ggsignif)
library(randomForest)
library(pscl)
library(lmtest)
library(multtest)
library(randomForestExplainer)
rm(list=ls())

##defining all three spatial resolutions
#the script has to be run for each resolution seperately
resolution<-1171
# resolution<-295
# resolution<-3267

##load the grid points
#by now grid points are associated with:
#- observed LD for FP and HG, as well as languages and families
#- number of times observed LD is higher than expected counts from 500 random simulations
#- all environmental information for three different spatial scales
load(paste("output/005_addingPredictors/randPtsLangPoissEnv_",resolution,".Rdata",sep=""))


##adding latitude as a predictor to the grid points
reg.spdf$latitude<-abs(reg.spdf@coords[,2])

##only complete cases (no NA)
ptsDat.full<-reg.spdf@data[complete.cases(reg.spdf@data),]

##classification into peaks and troughs
#we use the alpha=[0.25, 0.75]
#with troughs being below and peaks above alpha
fpClass<-cut(ptsDat.full$fpRelSmall,breaks=c(-1,0.25,0.75,2),labels=c("trough","exp","peak"))
table(fpClass)

hgClass<-cut(ptsDat.full$hgRelSmall,breaks=c(-1,0.25,0.75,2),labels=c("trough","exp","peak"))
table(hgClass)

hgFamClass<-cut(ptsDat.full$hgFamRelSmall,breaks=c(-1,0.25,0.75,2),labels=c("trough","exp","peak"))
table(hgFamClass)

fpFamClass<-cut(ptsDat.full$fpFamRelSmall,breaks=c(-1,0.25,0.75,2),labels=c("trough","exp","peak"))
table(fpFamClass)


####model for FP lang----

##create a df that is simple to use in the model
ptsDat<-data.frame(precip_var=ptsDat.full$per_cv_2ad,
                   temp_mean=ptsDat.full$temp_mean_2ad,
                   wettest=ptsDat.full$per_wetqu_2ad,
                   n_warm_month=ptsDat.full$n_warm_month_2ad,
                   warmest=ptsDat.full$temp_warmqu_2ad,
                   grass=ptsDat.full$gras_2ad,
                   pop=ptsDat.full$pop_2ad,
                   dist_river=ptsDat.full$dist_river,
                   dist_ocean=ptsDat.full$dist_ocean,
                   elevation=ptsDat.full$elev,
                   roughness=ptsDat.full$elevSD,
                   precip_var2=ptsDat.full$per_cv_2ad_02,
                   temp_mean2=ptsDat.full$temp_mean_2ad_02,
                   wettest2=ptsDat.full$per_wetqu_2ad_02,
                   n_warm_month2=ptsDat.full$n_warm_month_2ad_02,
                   warmest2=ptsDat.full$temp_warmqu_2ad_02,
                   grass2=ptsDat.full$gras_2ad_02,
                   pop2=ptsDat.full$pop_2ad_02,
                   dist_river2=ptsDat.full$dist_river_02,
                   dist_ocean2=ptsDat.full$dist_ocean_02,
                   elevation2=ptsDat.full$elev_02,
                   roughness2=ptsDat.full$elevSD_02,
                   precip_var0=ptsDat.full$per_cv_2ad_0,
                   temp_mean0=ptsDat.full$temp_mean_2ad_0,
                   wettest0=ptsDat.full$per_wetqu_2ad_0,
                   n_warm_month0=ptsDat.full$n_warm_month_2ad_0,
                   warmest0=ptsDat.full$temp_warmqu_2ad_0,
                   grass0=ptsDat.full$gras_2ad_0,
                   pop0=ptsDat.full$pop_2ad_0,
                   dist_river0=ptsDat.full$dist_river_0,
                   dist_ocean0=ptsDat.full$dist_ocean_0,
                   elevation0=ptsDat.full$elev_0,
                   roughness0=ptsDat.full$elevSD_0,
                   latitude=ptsDat.full$latitude)

#remove latitudinal trends from climate variables for all three scales
ptsDat$precip_var<-lm(precip_var~latitude,ptsDat)$residuals
ptsDat$temp_mean<-lm(temp_mean~latitude,ptsDat)$residuals
ptsDat$wettest<-lm(wettest~latitude,ptsDat)$residuals
ptsDat$n_warm_month<-lm(n_warm_month~latitude,ptsDat)$residuals
ptsDat$warmest<-lm(warmest~latitude,ptsDat)$residuals

ptsDat$precip_var0<-lm(precip_var0~latitude,ptsDat)$residuals
ptsDat$temp_mean0<-lm(temp_mean0~latitude,ptsDat)$residuals
ptsDat$wettest0<-lm(wettest0~latitude,ptsDat)$residuals
ptsDat$n_warm_month0<-lm(n_warm_month0~latitude,ptsDat)$residuals
ptsDat$warmest0<-lm(warmest0~latitude,ptsDat)$residuals

ptsDat$precip_var2<-lm(precip_var2~latitude,ptsDat)$residuals
ptsDat$temp_mean2<-lm(temp_mean2~latitude,ptsDat)$residuals
ptsDat$wettest2<-lm(wettest2~latitude,ptsDat)$residuals
ptsDat$n_warm_month2<-lm(n_warm_month2~latitude,ptsDat)$residuals
ptsDat$warmest2<-lm(warmest2~latitude,ptsDat)$residuals

#adding the target variable
ptsDat$ns<-fpClass

#removing all grid points that are inside alpha=[0.25,0.75]
ptsDat.s<-ptsDat[ptsDat$ns!="exp",]

ptsDat.s$ns<-factor(as.character(ptsDat.s$ns))

##accounting for unbalanced sampling of peaks and troughs
#the more frequent class is only allowed to be 25% more frequent
wgts<-table(ptsDat.s$ns)
wgts.s<-wgts

wgts.s[which.max(wgts)]<-max(wgts[-which.max(wgts)])+0.25*max(wgts[-which.max(wgts)])

if(max(wgts.s)>max(wgts)){
  wgts.s[which.max(wgts.s)]<-max(wgts)
}

#random forest classification
set.seed(1)
rf.fp <- randomForest(formula=ns~.,
                      data = ptsDat.s,
                      ntree=5000,
                      importance=T,
                      localImp=T,
                      sampsize=as.numeric(wgts.s),
                      strata=ptsDat.s$ns
)
print(rf.fp)
save(rf.fp,file=paste("output/006_prediction/rfFP_",resolution,".Rdata",sep=""))

#creating an error df with all required information from the classification (e.g. error rates)
errors.all<-data.frame(error=as.numeric(rf.fp$confusion[,3]),
                       effect=c("peak","trough"),
                       subsistance=rep("FP",2),
                       level=rep("language",2),
                       type=rep("all pred.",2),
                       totErr=rep(mean(rf.fp$err.rate[,1]),2))


####model for hg lang----

ptsDat$ns<-NULL

#adding target variable
ptsDat$ns<-hgClass

ptsDat.s<-ptsDat[ptsDat$ns!="exp",]

ptsDat.s$ns<-factor(as.character(ptsDat.s$ns))

#unbalanced sampling
wgts<-table(ptsDat.s$ns)
wgts.s<-wgts

wgts.s[which.max(wgts)]<-max(wgts[-which.max(wgts)])+0.25*max(wgts[-which.max(wgts)])

if(max(wgts.s)>max(wgts)){
  wgts.s[which.max(wgts.s)]<-max(wgts)
}

#model
set.seed(1)
rf.hg <- randomForest(formula=ns~.,
                      data = ptsDat.s,
                      ntree=5000,
                      importance=T,
                      localImp=T,
                      sampsize=as.numeric(wgts.s),
                      strata=ptsDat.s$ns
)
print(rf.hg)
save(rf.hg,file=paste("output/006_prediction/rfHG_",resolution,".Rdata",sep=""))

errors.all<-rbind(errors.all,
                  data.frame(error=as.numeric(rf.hg$confusion[,3]),
                             effect=c("peak","trough"),
                             subsistance=rep("HG",2),
                             level=rep("language",2),
                             type=rep("all pred.",2),
                             totErr=rep(mean(rf.hg$err.rate[,1]),2))
)


####model for fp family----
##for families, different environmental information is needed (e.g. climate from 6000bc)
##therefore a new df is created
ptsDat<-data.frame(precip_var=ptsDat.full$per_cv_6bc,
                   temp_mean=ptsDat.full$temp_mean_6bc,
                   wettest=ptsDat.full$per_wetqu_6bc,
                   n_warm_month=ptsDat.full$n_warm_month_6bc,
                   warmest=ptsDat.full$temp_warmqu_6bc,
                   grass=ptsDat.full$gras_6bc,
                   pop=ptsDat.full$pop_6bc,
                   dist_river=ptsDat.full$dist_river,
                   dist_ocean=ptsDat.full$dist_ocean,
                   elevation=ptsDat.full$elev,
                   roughness=ptsDat.full$elevSD,
                   precip_var2=ptsDat.full$per_cv_6bc_02,
                   temp_mean2=ptsDat.full$temp_mean_6bc_02,
                   wettest2=ptsDat.full$per_wetqu_6bc_02,
                   n_warm_month2=ptsDat.full$n_warm_month_6bc_02,
                   warmest2=ptsDat.full$temp_warmqu_6bc_02,
                   grass2=ptsDat.full$gras_6bc_02,
                   pop2=ptsDat.full$pop_6bc_02,
                   dist_river2=ptsDat.full$dist_river_02,
                   dist_ocean2=ptsDat.full$dist_ocean_02,
                   elevation2=ptsDat.full$elev_02,
                   roughness2=ptsDat.full$elevSD_02,
                   precip_var0=ptsDat.full$per_cv_6bc_0,
                   temp_mean0=ptsDat.full$temp_mean_6bc_0,
                   wettest0=ptsDat.full$per_wetqu_6bc_0,
                   n_warm_month0=ptsDat.full$n_warm_month_6bc_0,
                   warmest0=ptsDat.full$temp_warmqu_6bc_0,
                   grass0=ptsDat.full$gras_6bc_0,
                   pop0=ptsDat.full$pop_6bc_0,
                   dist_river0=ptsDat.full$dist_river_0,
                   dist_ocean0=ptsDat.full$dist_ocean_0,
                   elevation0=ptsDat.full$elev_0,
                   roughness0=ptsDat.full$elevSD_0,
                   latitude=ptsDat.full$latitude)

#removing latitudinal trends from climate variables for all scales
ptsDat$precip_var<-lm(precip_var~latitude,ptsDat)$residuals
ptsDat$temp_mean<-lm(temp_mean~latitude,ptsDat)$residuals
ptsDat$wettest<-lm(wettest~latitude,ptsDat)$residuals
ptsDat$n_warm_month<-lm(n_warm_month~latitude,ptsDat)$residuals
ptsDat$warmest<-lm(warmest~latitude,ptsDat)$residuals

ptsDat$precip_var0<-lm(precip_var0~latitude,ptsDat)$residuals
ptsDat$temp_mean0<-lm(temp_mean0~latitude,ptsDat)$residuals
ptsDat$wettest0<-lm(wettest0~latitude,ptsDat)$residuals
ptsDat$n_warm_month0<-lm(n_warm_month0~latitude,ptsDat)$residuals
ptsDat$warmest0<-lm(warmest0~latitude,ptsDat)$residuals

ptsDat$precip_var2<-lm(precip_var2~latitude,ptsDat)$residuals
ptsDat$temp_mean2<-lm(temp_mean2~latitude,ptsDat)$residuals
ptsDat$wettest2<-lm(wettest2~latitude,ptsDat)$residuals
ptsDat$n_warm_month2<-lm(n_warm_month2~latitude,ptsDat)$residuals
ptsDat$warmest2<-lm(warmest2~latitude,ptsDat)$residuals

#adding target variable
ptsDat$ns<-fpFamClass

ptsDat.s<-ptsDat[ptsDat$ns!="exp",]

ptsDat.s$ns<-factor(as.character(ptsDat.s$ns))

#unbalanced sampling
wgts<-table(ptsDat.s$ns)
wgts.s<-wgts

wgts.s[which.max(wgts)]<-max(wgts[-which.max(wgts)])+0.25*max(wgts[-which.max(wgts)])

if(max(wgts.s)>max(wgts)){
  wgts.s[which.max(wgts.s)]<-max(wgts)
}

#model
set.seed(1)
rf.fpFam <- randomForest(formula=ns~.,
                         data = ptsDat.s,
                         ntree=5000,
                         importance=T,
                         localImp=T,
                         sampsize=as.numeric(wgts.s),
                         strata=ptsDat.s$ns
)
print(rf.fpFam)
save(rf.fpFam,file=paste("output/006_prediction/rfFPFam_",resolution,".Rdata",sep=""))

errors.all<-rbind(errors.all,
                  data.frame(error=as.numeric(rf.fpFam$confusion[,3]),
                             effect=c("peak","trough"),
                             subsistance=rep("FP",2),
                             level=rep("family",2),
                             type=rep("all pred.",2),
                             totErr=rep(mean(rf.fpFam$err.rate[,1]),2))
)

####model for hg family----
ptsDat$ns<-NULL

#adding target variable
ptsDat$ns<-hgFamClass

ptsDat.s<-ptsDat[ptsDat$ns!="exp",]

ptsDat.s$ns<-factor(as.character(ptsDat.s$ns))

#unbalanced sampling
wgts<-table(ptsDat.s$ns)
wgts.s<-wgts

wgts.s[which.max(wgts)]<-max(wgts[-which.max(wgts)])+0.25*max(wgts[-which.max(wgts)])

if(max(wgts.s)>max(wgts)){
  wgts.s[which.max(wgts.s)]<-max(wgts)
}

#model
set.seed(1)
rf.hgFam <- randomForest(formula=ns~.,
                         data = ptsDat.s,
                         ntree=5000,
                         importance=T,
                         localImp=T,
                         sampsize=as.numeric(wgts.s),
                         strata=ptsDat.s$ns
)
print(rf.hgFam)
save(rf.hgFam,file=paste("output/006_prediction/rfHGFam_",resolution,".Rdata",sep=""))

errors.all<-rbind(errors.all,
                  data.frame(error=as.numeric(rf.hgFam$confusion[,3]),
                             effect=c("peak","trough"),
                             subsistance=rep("HG",2),
                             level=rep("family",2),
                             type=rep("all pred.",2),
                             totErr=rep(mean(rf.hgFam$err.rate[,1]),2))
)

write.csv(errors.all,paste("output/006_prediction/errorsAll_",resolution,".csv",sep=""))

#####drawing the error plot----

errors.allP<-errors.all[errors.all$type=="all pred.",]
p11<-ggplot(errors.allP, aes(x=effect,y=error, fill=effect)) + 
  geom_bar(stat = "identity") + 
  facet_grid(subsistance~level) + 
  ylim(0,.5) + xlab('')+
  scale_fill_manual(values=rep(c('red','blue'),1), guide=F)+ 
  theme(axis.text.x = element_text(angle = 90, hjust = 1))+
  theme_minimal()

p11

#####computation of variable importance----

varImp.fp.df <- measure_importance(rf.fp)
varImp.hgFam.df <- measure_importance(rf.hgFam)
varImp.hg.df <- measure_importance(rf.hg)
varImp.fpFam.df <- measure_importance(rf.fpFam)

save(varImp.fp.df,file=paste("output/006_prediction/varImpFP_",resolution,".Rdata",sep=""))
save(varImp.hg.df,file=paste("output/006_prediction/varImpHg_",resolution,".Rdata",sep=""))
save(varImp.hgFam.df,file=paste("output/006_prediction/varImpHgFam_",resolution,".Rdata",sep=""))
save(varImp.fpFam.df,file=paste("output/006_prediction/varImpFPFam_",resolution,".Rdata",sep=""))