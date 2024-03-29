library(sva)
library(tidyverse)
library(invgamma)


#Simulation studies recreated to my best abilities from 
#"A general framework for multiple testing dependence" (Leek et al. 2008)

#generate data X:
#X = BS + Gamma*G + U.

m = 1000
n = 20
r = 2

sigma_i = rinvgamma(m, 10, 9)
U = t(sapply(sigma_i, function(x) rnorm(20, mean = 0, sd = x)))

b1 = rnorm(m, mean = 0, sd = 1)
b2 = mapply(mu = c(rep(0, 300), rep(3.1, m - 300)),
             sigma = c(rep(2.5, 300), rep(1, m - 300)),
             function(mu, sigma) rnorm(1, mean = mu, sd = sigma))
B = cbind(b1, b2)
S = matrix(c(rep(1, n), rep(0, 10), rep(1, 10)), byrow = T, ncol = n)

Gamma = t(mapply(mu = c(rep(0, m)),
                 sigma = c(rep(2.5, m)),
                 function(mu, sigma) rnorm(r, mean = mu, sd = sigma)))
Gamma[c(1:200, 701:m), 1] = 0 #only signal from genes 300-700 in SV1
Gamma[c(1:400, 901:m), 2] = 0 #only signal from genes 500-900 in SV2
G = mapply(p = c(rep(.7, 10), rep(.2, 10)), #no need for intercept for kernel G. 
           function(p) rbernoulli(2, p))


X = B %*% S + Gamma %*% G + U


#run SVA on our simulation. 
pdf("sva_simulation.pdf", width=6, height=4)
nullMod = t(S)[, 1]
n.sv = num.sv(X, t(S), method = "be")
svobj = sva(X, t(S), nullMod, n.sv = n.sv)

#visually look at predicted SVs. 
qplot(as.numeric(G[1 ,]), svobj$sv[, 1], xlab = "True SV1", ylab = "Est. SV1")
qplot(as.numeric(G[2 ,]), svobj$sv[, 2], xlab = "True SV2", ylab = "Est. SV2")

nullmodsv = cbind(nullMod, svobj$sv)
modsv = cbind(t(S), svobj$sv)
#run full regression.
fitsv = lm.fit(modsv, t(X))

#visually look at predicted coefficients
effect = c(rep("null", 300), rep("alt", m - 300))
qplot(B[, 1], fitsv$coefficients[1 ,], color = effect, main = round(cor(fitsv$coefficients[1 ,], B[, 1]), 2), alpha = .4, xlab = "True b_i1", ylab = "Est. b_i1")
qplot(B[, 2], fitsv$coefficients[2 ,], color = effect, main = round(cor(B[, 2], fitsv$coefficients[2 ,]), 2), alpha = .25, xlab = "True b_i2", ylab = "Est. b_i2")

effect = c(rep("null", 200), rep("alt", 500), rep("null", 300))
qplot(Gamma[, 1], fitsv$coefficients[3 ,], color = effect, main = round(cor(Gamma[, 1], fitsv$coefficients[3 ,]), 2), alpha = .4, xlab = "True gamma_i1", ylab = "Est. gamma_i1")

effect = c(rep("null", 400), rep("alt", 500), rep("null", 100))
qplot(Gamma[, 2], fitsv$coefficients[4 ,], color = effect, main = round(cor(Gamma[, 2], fitsv$coefficients[4 ,]), 2), alpha = .4, xlab = "True gamma_i2", ylab = "Est. gamma_i2")

#just compute p-value of b_12 = 0 using F statistics. 
pValuesSv = f.pvalue(X, modsv, nullmodsv)
#double check with existing function:
pValuesSV2 = rep(NA, 1000)
fstat = rep(NA, 1000)
for(i in 1:1000) { 
  dat = data.frame(x = X[i ,], pv = S[2 ,], sv1 = svobj$sv[, 1], sv2 = svobj$sv[, 2])
  dat_nullmod = lm(x ~ pv, dat)
  dat_mod = lm(x ~ pv + sv1 + sv2, dat)
  an = anova(dat_nullmod, dat_mod)
  pValuesSV2[i] = an$`Pr(>F)`[2]
  fstat[i] = an$F[2]
}


qValuesSv = p.adjust(pValuesSv, method = "BH")
qValuesSV2 = p.adjust(pValuesSV2, method = "BH")


plot(1:length(qValuesSV2[1:300])/(length(qValuesSV2[1:300])+1),sort(qValuesSV2[1:300]))
abline(a = 0, b = 1)
ks.test(qValuesSV2[1:300],"punif",0,1)

table(qValuesSV2[1:300] < .05)
table(qValuesSV2[301:1000] < .05)

fstat_rank = rank(-fstat)
true_rank = rank(-abs(b2))

qplot(true_rank, fstat_rank)
dev.off()
