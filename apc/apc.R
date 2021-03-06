apc2 <- function(R, ...)
{
  PVP <- checkPVPPAIRS(R, ...)
  D <- designmatrix(PVP)
  apcM <- APCFIT(PVP, D$X)
  B <- apcM$B
  s2VAR <-apcM$s2VAR
  A <- length(PVP$D$a)
  P <- length(PVP$D$p)
  C <- length(PVP$D$c)
  
  #
  # (0) Fitted rates
  #
  ETA <- D$X%*%B
  # Formula to compute only the variances of fitted rates, not any covariances.
  v <- rowSums((D$X%*%s2VAR)*D$X)
  # Scale the values such that naive formulae yield correct variances.
  v[v<0] <- NaN
  EFit <- matrix(1/v, nrow=A, ncol=P)
  OFit <- matrix((1/v)*exp(-ETA), nrow=A, ncol=P)
  FittedRates <- list(name = paste('Fitted', PVP$name),
                      events = EFit, 
                      offset = OFit, 
                      offset_tick = PVP$offset_tick, 
                      ages = R$ages, 
                      periods = R$periods);
  
  #
  # (1) Coefficents
  #
  XCO <- matrix(c(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, -1), nrow=4, byrow=TRUE)
  b <- XCO%*%B[1:3]
  v <- XCO%*%s2VAR[1:3,1:3]%*%t(XCO)
  s <- matrix(sqrt(diag(v)))
  c <- cbind(b - 1.96*s, b + 1.96*s)
  Coefficients <- cbind(b, s, c)
  dimnames(Coefficients) <- list(c("Intercept","LAT","NetDrift", "CAT"), c("Parameter","SD","CI Lo", "CI Hi"))
  # Wald test - NetDrift different from 0?
  X21 <- (b[3]/s[3])^2
  df1 <- 1
  PVAL1 <- pchisq(X21, df1,lower.tail = FALSE)
  
  #
  # (1b) Net Drift as estimated annual percentage change
  #
  b3 <- B[3];
  v3 <- s2VAR[3, 3];
  s3 <- sqrt(v3)
  c3 <- cbind(b3 - 1.96*s3, b3 + 1.96*s3)
  NetDrift <- cbind(b3, c3)
  NetDrift <- 100*(exp(NetDrift) - 1)
  dimnames(NetDrift) <- list( c(), c("Net Drift (%/year)", "CI Lo", "CI Hi") )
  
  #
  # (2) Age Deviations
  #
  a <- matrix(PVP$D$a)
  a0 <- PVP$RVals[1]
  a0LOC <- match(a0, a)
  
  ba <- D$XAD%*%B[D$Pt[[4]]]
  va <- D$XAD%*%s2VAR[D$Pt[[4]],D$Pt[[4]]]%*%t(D$XAD)
  sa <- matrix(sqrt(diag(va)))
  ca <- cbind(ba - 1.96*sa, ba + 1.96*sa)
  AgeDeviations <- cbind(a, ba, ca)
  dimnames(AgeDeviations) <- list(c(), c("Age", "Deviation", "CI Lo", "CI Hi"))
  # Wald test - any age deviations different from 0?
  X22 <- t(matrix(ba[2:(A-1)]))%*%solve(va[2:(A-1),2:(A-1)], matrix(ba[2:(A-1)]))
  df2 <- A - 2
  PVAL2 <- pchisq(X22, df2, lower.tail = FALSE)
  
  #
  # (3) Period Deviations
  #
  p <- matrix(PVP$D$p)
  p0 <- PVP$RVals[2]
  p0LOC <- match(p0, p)
  
  bp <- D$XPD%*%B[D$Pt[[5]]]
  vp <- D$XPD%*%s2VAR[D$Pt[[5]],D$Pt[[5]]]%*%t(D$XPD)
  sp <- matrix(sqrt(diag(vp)))
  cp <- cbind(bp - 1.96*sp, bp + 1.96*sp)
  PerDeviations <- cbind(p, bp, cp)
  dimnames(PerDeviations) <- list(c(), c("Period", "Deviation", "CI Lo", "CI Hi"))
  # Wald test - any period deviations different from 0?
  X23 <- t(matrix(bp[2:(P-1)]))%*%solve(vp[2:(P-1),2:(P-1)], matrix(bp[2:(P-1)]))
  df3 <- P - 2
  PVAL3 <- pchisq(X23, df3, lower.tail = FALSE)
  
  #
  # (4) Cohort Deviations incorporating the weighting
  #
  c <- matrix(PVP$D$c)
  c0 <- PVP$RVals[3]
  c0LOC <- match(c0, c)
  
  #
  # Construct P1 transformation from classical Holford Deviations to Weighted Deviations
  Xc <- cbind(matrix(1, C), c-c0)
  TMP <- table(PVP$D$DATA[,3])
  W <- matrix(as.vector(TMP))
  WXc <- (W%*%matrix(1,ncol=2))*Xc
  Rwc <- solve(t(Xc)%*%WXc,t(WXc))
  P1 <- diag(C) - Xc%*%Rwc
  # Update XCD matrix 
  D$XCD <- P1%*%D$XCD
    
  bc <- D$XCD%*%B[D$Pt[[6]]]
  vc <- D$XCD%*%s2VAR[D$Pt[[6]],D$Pt[[6]]]%*%t(D$XCD)
  sc <- matrix(sqrt(diag(vc)))
  cc <- cbind(bc - 1.96*sc, bc + 1.96*sc)
  CohDeviations <- cbind(c, bc, cc)
  dimnames(CohDeviations) <- list(c(), c("Cohort", "Deviation", "CI Lo", "CI Hi"))
  # Wald test - any cohort deviations different from 0?
  X24 <- t(matrix(bc[2:(C-1)]))%*%solve(vc[2:(C-1),2:(C-1)], matrix(bc[2:(C-1)]))
  df4 <- C - 2
  PVAL4 <- pchisq(X24, df4, lower.tail = FALSE)
  
  #
  # (5) Longitudinal Age Curve, centered on the reference cohort
  #
  
  D$XLA <- cbind(matrix(1, A), a-a0, D$XAD, matrix(1, A)%*%D$XCD[c0LOC,])
  lot <- log(PVP$offset_tick)
  lar <- lot + D$XLA%*%B[c(1, 2, D$Pt[[4]], D$Pt[[6]])]
  lav <- D$XLA%*%s2VAR[c(1, 2, D$Pt[[4]], D$Pt[[6]]), c(1, 2, D$Pt[[4]], D$Pt[[6]])]%*%t(D$XLA)
  las <- matrix(sqrt(diag(lav)))
  lac <- cbind(lar - 1.96*las, lar + 1.96*las)
  LongAge <- cbind(a, exp(lar), exp(lac))
  dimnames(LongAge) <- list(c(), c("Age", "Rate", "CILo", "CIHi"))
  
  
  
  #
  # (5b) Longitudinal Age Rate Ratios
  #
  TMP1 <- cbind(matrix(1, A), a-a0, D$XAD)
  TMP2 <- diag(0,nrow=A)
  TMP2[, is.element(a, a0)] <- 1
  TMP2 <- diag(A) - TMP2
  D$LAR <- TMP2%*%TMP1  
  larr <- D$LAR%*%B[c(1, 2, D$Pt[[4]])]
  larrv <- D$LAR%*%s2VAR[c(1, 2, D$Pt[[4]]), c(1, 2, D$Pt[[4]])]%*%t(D$LAR)
  larrs <- matrix(sqrt(diag(larrv)))
  larrc <- cbind(larr - 1.96*larrs, larr + 1.96*larrs)
  LongAgeRR <- cbind(a, exp(larr), exp(larrc))
  dimnames(LongAgeRR) <- list(c(), c("Age", "Rate Ratio", "CILo", "CIHi"))
  
  
  
  
  #
  # (6) Cross-Sectional Age Curve, centered on the reference period
  #
  D$XXA <- cbind(matrix(1, A), a-a0, -1*(a-a0), D$XAD, matrix(1, A)%*%D$XPD[p0LOC,])
  xar <- lot + D$XXA%*%B[c(1, 2, 3, D$Pt[[4]], D$Pt[[5]])]
  xav <- D$XXA%*%s2VAR[c(1, 2, 3, D$Pt[[4]], D$Pt[[5]]), c(1, 2, 3, D$Pt[[4]], D$Pt[[5]])]%*%t(D$XXA)
  xas <- matrix(sqrt(diag(xav)))
  xac <- cbind(xar - 1.96*xas, xar + 1.96*xas)
  CrossAge <- cbind(a, exp(xar), exp(xac))
  dimnames(CrossAge) <- list(c(), c("Age", "Rate", "CILo", "CIHi"))
  
  #
  # (6c) Ratio of Longitudinal-to-Cross-Sectional Age Curves
  #
  D$XLX <- cbind(a-a0, matrix(1,A)%*%D$XCD[c0LOC,], matrix(-1,A)%*%D$XPD[p0LOC,])
  lcr <- D$XLX%*%B[c(3, D$Pt[[6]], D$Pt[[5]])]
  lcv <- D$XLX%*%s2VAR[c(3, D$Pt[[6]], D$Pt[[5]]), c(3, D$Pt[[6]], D$Pt[[5]])]%*%t(D$XLX)
  lcs <- matrix(sqrt(diag(lcv)))
  lcc <- cbind(lcr - 1.96*lcs, lcr + 1.96*lcs)
  Long2CrossRR <- cbind(a, exp(lcr), exp(lcc))
  dimnames(Long2CrossRR) <- list(c(), c("Age", "Rate Ratio", "CILo", "CIHi"))
  
  #
  # (7) Fitted Temporal Trends centered on reference age
  #
  D$XPT <- cbind(matrix(1, P), p-p0, D$XPD, matrix(1,P)%*%D$XAD[a0LOC,])
  ftt <- lot + D$XPT%*%B[c(1, 3, D$Pt[[5]], D$Pt[[4]])]
  ftv <- D$XPT%*%s2VAR[c(1, 3, D$Pt[[5]], D$Pt[[4]]), c(1, 3, D$Pt[[5]], D$Pt[[4]])]%*%t(D$XPT)
  fts <- matrix(sqrt(diag(ftv)))
  ftc <- cbind(ftt - 1.96*fts, ftt + 1.96*fts)
  FittedTemporalTrends <- cbind(p, exp(ftt), exp(ftc))
  dimnames(FittedTemporalTrends) <- list(c(), c("Period", "Rate", "CILo", "CIHi"))
  
  #
  # (8) Period Rate Ratios
  #
  Xp <- cbind(matrix(1,P), p-p0, D$XPD)
  TMP <- diag(0,nrow=P)
  TMP[, is.element(p, p0)] <- 1
  PRR <- diag(P) - TMP
  D$XPR <- PRR%*%Xp
  pr <- D$XPR%*%B[c(1, 3, D$Pt[[5]])]
  vpr <- D$XPR%*%s2VAR[c(1, 3, D$Pt[[5]]), c(1, 3, D$Pt[[5]])]%*%t(D$XPR)
  sd <- matrix(sqrt(diag(vpr)))
  ci <- cbind(pr - 1.96*sd, pr + 1.96*sd)
  epr <- exp(pr)
  eci <- exp(ci)
  PeriodRR <- cbind(p, epr, eci)
  dimnames(PeriodRR) <- list(c(), c("Period", "Rate Ratio", "CILo", "CIHi"))
  
  # Wald test - any PRR different from 1?
  I <- 1:P
  INC8 <- I[!is.element(p,p0)]
  X28 <- t(matrix(pr[INC8]))%*%solve(vpr[INC8,INC8], matrix(pr[INC8]))
  df8 <- P - 1
  PVAL8 <- pchisq(X28, df8, lower.tail = FALSE)
  
  #
  # (9) Cohort Rate Ratios
  #
  c0 <- PVP$RVals[3]
  Xc <- cbind(matrix(1,C), c-c0, D$XCD)
  TMP <- diag(0,nrow=C)
  TMP[, is.element(c, c0)] <- 1
  CRR <- diag(C) - TMP
  D$XCR <- CRR%*%Xc
  cr <- D$XCR%*%B[c(1, 3, D$Pt[[6]])]
  vcr <- D$XCR%*%s2VAR[c(1, 3, D$Pt[[6]]), c(1, 3, D$Pt[[6]])]%*%t(D$XCR)
  sd <- matrix(sqrt(diag(vcr)))
  ci <- cbind(cr - 1.96*sd, cr + 1.96*sd)
  ecr <- exp(cr)
  eci <- exp(ci)
  CohortRR <- cbind(c, ecr, eci)
  dimnames(CohortRR) <- list(c(), c("Cohort", "Rate Ratio", "CILo", "CIHi"))
  
  # Wald test - any CRR different from 1?
  I <- 1:C
  INC9 <- I[!is.element(c,c0)]
  X29 <- t(matrix(cr[INC9]))%*%solve(vcr[INC9,INC9], matrix(cr[INC9]))
  df9 <- C - 1
  PVAL9 <- pchisq(X29, df9, lower.tail = FALSE)
  
  
  #
  # (9b) Fitted Cohort Pattern centered on the reference age
  #
  D$XCT <- cbind(matrix(1,C), c-c0, D$XCD, matrix(1,C)%*%D$XAD[a0LOC,])
  fcp <- lot + D$XCT%*%B[c(1, 3, D$Pt[[6]], D$Pt[[4]])]
  vcp <- D$XCT%*%s2VAR[c(1, 3, D$Pt[[6]], D$Pt[[4]]), c(1, 3, D$Pt[[6]], D$Pt[[4]])]%*%t(D$XCT)
  sd <- matrix(sqrt(diag(vcp)))
  ci <- cbind(fcp - 1.96*sd, fcp + 1.96*sd)
  efcp <- exp(fcp)
  eci <- exp(ci)
  FittedCohortPattern <- cbind(c, efcp, eci)
  dimnames(FittedCohortPattern) <- list(c(), c("Cohort", "Rate", "CILo", "CIHi"))
  
  #
  # (10) local drifts
  #
  
  # Values and vc-matrix for cohort deviations and net drift.
  XCB <- rbind(cbind(D$XCD, 0), 0)
  XCB[C+1,C-1] <- 1
  
  # Build contrast matrix to extract slopes from cohort deviations via  
  # sliding window analysis with bandwidth P
  x <- p - mean(p)
  DELTA <- floor(P/2)
  MESH <- p[2]-p[1]
  odd <- P%%2
  if (odd==1)
  {BANG <- (MESH*MESH)*2*(1/6)*DELTA*(DELTA+1)*(2*DELTA+1)} else
  {BANG <- (MESH*MESH)*0.5*((4/3)*(DELTA-1)*DELTA*(DELTA+1) + DELTA)}
  x_ <- (1/BANG)*t(x)
  
  K <- matrix(0, nrow=A, ncol=C)
  for (ag in 1:A) {
    # starting at the first age group, you have the most recent set of P cohorts
    i0 <- 1+A-ag
    i1 <- 1+A-ag+P-1
    K[ag, i0:i1] <- x_
  }
  CM <- cbind(K, matrix(1, nrow=A))
  g <- XCB%*%B[c(D$Pt[[6]], 3)]
  v <- XCB%*%s2VAR[c(D$Pt[[6]], 3), c(D$Pt[[6]], 3)]%*%t(XCB)
  ld <- CM%*%g
  vld <- CM%*%v%*%t(CM)
  sd <- matrix(sqrt(diag(vld)))
  ci <- cbind(ld - 1.96*sd, ld + 1.96*sd)
  eld <- 100*(exp(ld)-1)
  eci <- 100*(exp(ci)-1)
  LocalDrifts = cbind(matrix(a), eld, eci)
  dimnames(LocalDrifts) <- list(c(), c("Age", "Percent per Year", "CILo", "CIHi"))
  
  # Wald test - any age-specific drifts different from netDrift?
  CM0 <- CM
  CM0[,C+1] <- 0
  EDiff <- CM0%*%g
  VDiff <- CM0%*%v%*%t(CM0)
  # count degrees of freedom
  TMP <- qr(VDiff)
  dfld <- TMP$rank
  INCa <- seq(1, dfld)
  X210 <- t(EDiff[INCa])%*%solve(VDiff[INCa,INCa], EDiff[INCa])
  df10 <- dfld
  PVAL10 <- pchisq(X210, df10, lower.tail = FALSE)
  
  WaldTests <- matrix(
    c(X21, df1, PVAL1, X22, df2, PVAL2, 
      X23, df3, PVAL3, X24, df4, PVAL4, 
      X28, df8, PVAL8, X29, df9, PVAL9,
      X210, df10, PVAL10), 7, 3, byrow = TRUE)
  dimnames(WaldTests) <- list(
    c("NetDrift = 0", 
      "All Age Deviations = 0", 
      "All Period Deviations = 0", 
      "All Cohort Deviations = 0", 
      "All Period RR = 1", 
      "All Cohort RR = 1", 
      "All Local Drifts = Net Drift"),
    c("X2", "df", "P-Value"))
  
  V <- list(va = va,
            vp = vp,
            vc = vc,
            lav = lav,
            xav = xav,
            ftv = ftv,
            vpr = vpr,
            vcr = vcr,
            vld = vld)
  
  M <- list(Inputs = PVP,
            FittedRates = FittedRates,
            Coefficients = Coefficients,
            AgeDeviations = AgeDeviations,
            PerDeviations = PerDeviations,
            CohDeviations = CohDeviations,
            LongAge = LongAge, 
            LongAgeRR = LongAgeRR,
            CrossAge = CrossAge,
            Long2CrossRR = Long2CrossRR,
            FittedTemporalTrends = FittedTemporalTrends,
            PeriodRR = PeriodRR,
            CohortRR = CohortRR,
            FittedCohortPattern = FittedCohortPattern,
            LocalDrifts = LocalDrifts,
            Waldtests = WaldTests,
            Variances = V,
            APCModel = apcM,
            Pt = D$Pt,
            NetDrift = NetDrift,
            Matrices = D)
  
  
}


checkPVPPAIRS <- function(R, OverDispersion = 1, offset_tick = 10^5, zero_fill = 0.1, RVals = c(NaN, NaN, NaN))
{
  D <- rates2data_set(R)
  
  if (all(is.nan(RVals)))
    # Calculate default reference values    
   {
    aM <- length(D$a)
    pN <- length(D$p)
    abar <- floor((aM+1)/2)
    pbar <- floor((pN+1)/2)
    cbar <- pbar - abar + aM
    abar <- D$a[abar]
    pbar <- D$p[pbar]
    cbar <- D$c[cbar]
    RVals <- c(abar, pbar, cbar)
    }
  else
  # Valdidate user-supplied reference values 
  {
  RVals <- floor(RVals)
  
  A <- is.element(RVals[1], D$a)
  if (!A)
  {
   RVals[1] <- floor(RVals[1]) + 0.5
   A <- is.element(RVals[1], D$a)
  }
  B <- is.element(RVals[2], D$p)
  if (!B)
  {
    RVals[2] <- floor(RVals[2]) + 0.5
    B <- is.element(RVals[2], D$p)
  }
  C <- is.element(RVals[3], D$c)
  if (!C)
  {
    RVals[3] <- floor(RVals[3]) + 0.5
    C <- is.element(RVals[3], D$c)
  }
  
  if (!(A && B && C))
    stop("Invalid Age, Period, or Cohort reference value.")
  end
  
  
  if (!(RVals[3] == RVals[2] - RVals[1]))
    stop("Inconsistent Age, Period, and Cohort reference values.")  
  end
  
  }
  # Replace 0 events with zero_fill value.
  e <- matrix(D$DATA[,4])
  e[e==0] <- zero_fill
  D$DATA[,4] <- e
  
  PVP <- list(D = D, 
              RVals = RVals, 
              OverDispersion = OverDispersion, 
              offset_tick = offset_tick,
              zero_fill = zero_fill)
  
}

rates2data_set <- function(R) {
  
  
  R$events
  R$offset
  
  M <- nrow(R$events)
  N <- ncol(R$events)
  
  da <- R$a[2:(M+1)] - R$a[1:M]
  D.a <- R$a[1:M] + 0.5*da
  
  dp <- R$p[2:(N+1)] - R$p[1:N]
  D.p <- R$p[1:N] + 0.5*dp
  
  
  
  ADATA <- kronecker(matrix(1, nrow=N),  matrix(D.a, nrow=M))
  PDATA <- kronecker(matrix(D.p, nrow=N), matrix(1, nrow=M))
  CDATA <- PDATA - ADATA
  D.c <- sort(c(unique(CDATA)))
  E <- c(R$events)
  O <- c(R$offset)
  D.DATA = cbind(ADATA, PDATA, CDATA, E, O)
  colnames(D.DATA)<-c("Age","Period","Cohort","Events","Offset")
  
  
  D <- list(name = R$name,
            description = R$description,
            DATA = D.DATA, 
            a = D.a,
            p = D.p,
            c = D.c)
                     
}

APCFIT = function(PVP, X)
{
  Y <- PVP$D$DATA[,4:5];
  offset <- matrix(log(Y[,2]))
  y <- matrix(Y[,1])
  ly <- log(y)
  
  n <- nrow(X)
  p <- ncol(X)
  W <- y
  WX <- (W%*%matrix(1,ncol=p))*X
  z <- (ly - offset)
  B <- solve(t(X)%*%WX,t(WX)%*%z)
  V <- solve(t(X)%*%WX)
  u <- matrix(Y[,2]*exp(X%*%B))
  wr2 <- matrix(W*(z-X%*%B)^2)
  DEVRESIDS <- sign(y-u)*sqrt(wr2)
  DEV <- sum(wr2)
  
  if (PVP$OverDispersion==1){
    s2 <- max(1, DEV/(n-p))
    }  else    {s2 <- 1}
  if (is.infinite(s2))
   {s2 <- 1}
  
  s2V = s2*V
  APCMODEL <- list(B = B, 
                   s2 = s2,
                   s2VAR = s2V, 
                   DEV = DEV, 
                   DevResids = DEVRESIDS)
  
  
}

designmatrix <- function(PVP)
{
  N <- nrow(PVP$D$DATA)
  J <- matrix(1, nrow = N)
  
  a <- matrix(PVP$D$DATA[,1])
  avals <- PVP$D$a
  aM <- length(avals)
  
  
  p <- matrix(PVP$D$DATA[,2])
  pvals <- PVP$D$p
  pN <- length(pvals)
  
  c <- matrix(PVP$D$DATA[,3])
  cvals <- PVP$D$c
  cK <- length(cvals)
  
  # Age 
  Ad <- matrix(NaN,nrow=N,ncol=aM)
  for (i in 1:aM)
    Ad[,i] <- a==avals[i]
  end

  # Per
  Pd <- matrix(NaN,nrow=N,ncol=pN)
  for (i in 1:pN)
   Pd[,i] <- p==pvals[i]
  end
  
  # Coh
  Cd <- matrix(NaN,nrow=N,ncol=cK)
  for (i in 1:cK)
    Cd[,i] <- c==cvals[i]
  end
  
  abar <- PVP$RVals[1]
  pbar <- PVP$RVals[2]
  cbar <- PVP$RVals[3]
  
  a0 <- a - abar
  p0 <- p - pbar
  c0 <- c - cbar
  
  # Center age, period, and cohort on mid-age, mid-period, or mid-cohort, or on
  # user-specified values
  
  Xa <- cbind(J, a0)
  Ra <- solve(t(Xa)%*%Xa,t(Xa))
  XAD <- diag(N) - Xa%*%Ra
  
  Xp <- cbind(J, p0)
  Rp <- solve(t(Xp)%*%Xp,t(Xp))
  XPD <- diag(N) - Xp%*%Rp
  
  Xc <- cbind(J, c0)
  Rc <- solve(t(Xc)%*%Xc,t(Xc))
  XCD <- diag(N) - Xc%*%Rc
  
  Ad0 <- XAD%*%Ad
  Pd0 <- XPD%*%Pd
  Cd0 <- XCD%*%Cd
  
  X <- cbind(J, a0, c0, Ad0[,2:(aM-1)], Pd0[,2:(pN-1)], Cd0[,2:(cK-1)])
  
  pA <- ncol(Ad)
  pP <- ncol(Pd)
  pC <- ncol(Cd)
  
  Pt <- vector("list", 6)
  Pt[[1]] <- 1
  Pt[[2]] <- 2
  Pt[[3]] <- 3
  Pt[[4]] <- 4:(pA+1)
  Pt[[5]] <- (pA+2):(pA+pP-1)
  Pt[[6]] <- (pA+pP):(pA+pP+pC-3)
  
  # Compute contrast matrices to convert parameters to deviations
  
  Xa <- cbind(matrix(1, nrow = aM), matrix(avals) - abar)
  Ra <- solve(t(Xa)%*%Xa,t(Xa))
  XAD <- diag(aM) - Xa%*%Ra
  XAD <- matrix(XAD[,2:(aM-1)], nrow = aM)
  
  Xp <- cbind(matrix(1, nrow = pN), matrix(pvals) - pbar)
  Rp <- solve(t(Xp)%*%Xp,t(Xp))
  XPD <- diag(pN) - Xp%*%Rp
  XPD <- matrix(XPD[,2:(pN-1)], nrow = pN)
  
  Xc <- cbind(matrix(1, nrow = cK), matrix(cvals) - cbar)
  Rc <- solve(t(Xc)%*%Xc,t(Xc))
  XCD <- diag(cK) - Xc%*%Rc
  XCD <- matrix(XCD[,2:(cK-1)], nrow = cK)
  
  
  D <- list(X = X, Pt = Pt, XAD = XAD, XPD = XPD, XCD = XCD)
}


plot.apc <- function(M)
{
  
  par(mfrow = c(4,3))
  
 
  DATA <- cbind(matrix(M$LongAge[,1]), (M$LongAge[,c(2,3,4)]))
  dimnames(DATA) <- list(c(), c("Age", "Rate", "CILo", "CIHi"))
  pcurve(DATA, col = "darkred", colf = "pink", lwd = 3, cex = 1.0, pch = 21)
  title(main = "Longitudinal Age Curve", cex.main = 1)
  
  DATA <- cbind(matrix(M$CrossAge[,1]), (M$CrossAge[,c(2,3,4)]))
  dimnames(DATA) <- list(c(), c("Age", "Rate", "CILo", "CIHi"))
  pcurve(DATA, lwd = 3, col = "darkred", colf = "pink", cex = 1.0, pch = 21)
  title(main = "Cross-Sectional Age Curve", cex.main = 1)
  
  pcurve(M$Long2CrossRR, lwd = 3, col = "darkred", colf = "pink", cex = 1.0, pch = 21)
  abline(1,0, lty = 3)
  title(main = "Long vs. Cross RR", cex.main = 1)
  
  pcurve(M$FittedTemporalTrends, col = "steelblue4", colf = "slategray1", lwd = 3, cex = 1.0, pch = 21)
  title(main = "Fitted Temporal Trends", cex.main = 1)
  
  pcurve(M$PeriodRR, col = "steelblue4", colf = "slategray1", lwd = 3, cex = 1.0, pch = 21)
  abline(1, 0, lty = 3)
  title(main = "Period RR", cex.main = 1)
  
  pcurve(M$CohortRR, col = "seagreen4", colf = "darkseagreen1", lwd = 3, cex = 1.0, pch = 21)
  abline(1, 0, lty = 3)
  title(main = "Cohort RR", cex.main = 1)
  
  pcurve(M$LocalDrifts, col = "black", colf = "grey88", lwd = 3, cex = 1.0, pch = 21)
  abline(0, 0, lty = 3)
  title(main = "Local Drifts", cex.main = 1)
  
  pcurve(M$AgeDeviations, col = "darkred", colf = "pink", lwd = 3, cex = 1.0, pch = 21)
  abline(0, 0, lty = 3)
  title(main = "Age Deviations", cex.main = 1)

  pcurve(M$PerDeviations, col = "steelblue4", colf = "slategray1", lwd = 3 , cex = 1.0, pch = 21)
  abline(0, 0, lty = 3)
  title(main = "Period Deviations", cex.main = 1)
 
  pcurve(M$CohDeviations, col = "seagreen4", colf = "darkseagreen1", lwd = 3, cex = 1.0, pch = 21)
  abline(0, 0, lty = 3)
  title(main = "Cohort Deviations", cex.main = 1)
  
  pcurve(M$FittedCohortPattern, col = "seagreen4", colf = "darkseagreen1", lwd = 3, cex = 1.0, pch = 21)
  abline(0, 0, lty = 3)
  title(main = "Fitted Cohort Pattern", cex.main = 1)
  
}

pcurve <- function(DATA, col = 'blue', colf = 'blue', bg = 'grey99', pch = 1, type = 'b', lty = 1, lwd = 2, XLim = NA, cex = 1.5)
  {
    
    
    x <- DATA[,1]
    rangex <- range(x)[2]-range(x)[1]
    if (is.na(XLim[1])) {XLim <- c(min(x)-0.05*rangex, max(x)+0.05*rangex)}
    xl <- dimnames(DATA)[[2]][1] 
    
    y <- DATA[,2]
    rangey <- range(y)[2]-range(y)[1]
    YLim <- c(min(y) - 0.05*rangey, max(y) + 0.05*rangey)
    yl <- dimnames(DATA)[[2]][2]
    
    
    
    
    if (ncol(DATA)==4){
      xci <- c(x, rev(x))
      yci <- c(DATA[, 3], rev(DATA[, 4]))
      rangey <- range(yci)[2]-range(yci)[1]
      YLim <- c(min(yci) - 0.05*rangey, max(yci) + 0.05*rangey)}
    else {yci <- NULL}
    
    
    plot(x, y, col = col, pch = pch, type = type, lty = lty, lwd = lwd, cex = cex, 
         xlab = xl, ylab = yl, xlim = XLim, ylim = YLim, las = 1, bg = bg)   
    
    if (!is.null(yci[1])){
      polygon(xci, yci, col = colf, border = colf)
    }
    
    points(x, y, col = col, pch = pch, type = type, lty = lty, lwd = lwd, cex = cex, 
           xlab = xl, ylab = yl, xlim = XLim, ylim = YLim, las = 1, bg = bg)   
    
  }


line.apc <- function(M, Function)
{
  
  par(cex.lab = 1.5)
  
  if (Function == "AgeDeviations") {
    pcurve(M$AgeDeviations, col = "darkred", colf = "pink", lwd = 3, cex = 2.5, pch = 21)
    abline(0, 0, lty = 3)
    title(main = "Age Deviations", cex.main = 1.5)
  } else if (Function == "PerDeviations") {
    pcurve(M$PerDeviations, col = "steelblue4", colf = "slategray1", lwd = 3 , cex = 2.5, pch = 21)
    abline(0, 0, lty = 3)
    title(main = "Period Deviations", cex.main = 1.5)
  } else if (Function == "CohDeviations") {
    pcurve(M$CohDeviations, col = "seagreen4", colf = "darkseagreen1", lwd = 3, cex = 2.5, pch = 21)
    abline(0, 0, lty = 3)
    title(main = "Cohort Deviations", cex.main = 1.5)
  } else if (Function == "LongAge") {
    pcurve(M$LongAge, col = "darkred", colf = "pink", lwd = 3, cex = 2.5, pch = 21)
    title(main = "Longitudinal Age Curve", cex.main = 1.5)
  } else if (Function == "CrossAge") {
    pcurve(M$CrossAge, lwd = 3, col = "darkred", colf = "pink", cex = 2.5, pch = 22)
    title(main = "Cross-Sectional Age Curve", cex.main = 1.5)
  } else if (Function == "Long2CrossRR") {
    pcurve(M$Long2CrossRR, col = "darkred", colf = "pink", lwd = 4, type = "l")
    abline(1,0, lty = 3)
    title(main = "Long vs. Cross RR", cex.main = 1.5)
  } else if (Function == "FittedTemporalTrends") {
    pcurve(M$FittedTemporalTrends, col = "steelblue4", colf = "slategray1", lwd = 3, cex = 2.5, pch = 21)
    title(main = "Fitted Temporal Trends", cex.main = 1.5)
  } else if (Function == "PeriodRR") {
    pcurve(M$PeriodRR, col = "steelblue4", colf = "slategray1", lwd = 3, cex = 2.5, pch = 21)
    abline(1, 0, lty = 3)
    title(main = "Period RR", cex.main = 1.5)
  } else if (Function == "CohortRR") {
    pcurve(M$CohortRR, col = "seagreen4", colf = "darkseagreen1", lwd = 3, cex = 2.5, pch = 21)
    abline(1, 0, lty = 3)
    title(main = "Cohort RR", cex.main = 1.5)
  } else if (Function == "FittedCohortPattern"){
    pcurve(M$FittedCohortPattern, col = "seagreen4", colf = "darkseagreen1", lwd = 3, cex = 2.5, pch = 21)
    title(main = "Fitted Cohort Pattern", cex.main = 1.5)
  } else if (Function == "LocalDrifts") {
    pcurve(M$LocalDrifts, col = "black", colf = "grey88", lwd = 3, cex = 2.5, pch = 21)
    NDPE <- cbind(matrix(M$NetDrift[,1]))
    NDLL <- cbind(matrix(M$NetDrift[,2]))
    NDUP <- cbind(matrix(M$NetDrift[,3]))
    abline(NDPE, 0, col = "gray30", lty = 1, lwd = 2)
    abline(NDLL, 0, col = "gray50", lty = 2, lwd = 1.5)
    abline(NDUP, 0, col = "gray50", lty = 2, lwd = 1.5)
    title(main = "Local Drifts with Net Drift", cex.main = 1.5)
  } else {
    
  }
  
  
}

rateratio <- function(R1, R2)
{
  
  r1 <- R1$offset_tick*R1$events/R1$offset
  r2 <- R2$offset_tick*R2$events/R2$offset
  
  rr = r1/r2
  
  RR <- list(name = paste(R1$name, R2$name, sep = " vs. "), RateRatio = rr, ages = R1$ages, periods = R1$periods) 
  
  
}

type <- function(R, comp = 'r')
{
  A <- nrow(R$events)
  P <- ncol(R$events)
  
  if (comp == "r") {
    T <- R$offset_tick*R$events/R$offset
    dn <- paste('Rates - ', R$name)
    
  } else if (comp == "e") {
    T <- R$events
    dn <- paste("Events -", R$name)
    
  } else if (comp == "o") {
    T <- R$offset
    dn <- paste('Offset - ', R$name)
    
  } else if (comp == "eo") {
  
    DATA <- matrix(NaN, nrow = A, ncol = 2*P)
    DATA[,seq.int(1, 2*P, 2)]<-R$events
    DATA[,seq.int(2, 2*P, 2)]<-R$offset
    T <- DATA
    dn <- paste("Events & Offset -", R$name)
    
  } else if (comp == "er") {
    r <- R$offset_tick*R$events/R$offset
    DATA <- matrix(NaN, nrow = A, ncol = 2*P)
    DATA[,seq.int(1, 2*P, 2)]<-R$events
    DATA[,seq.int(2, 2*P, 2)]<-r
    T <- DATA
    dn <- paste("Events and Rates - ", R$name)
   
  } else if (comp == "eor") {
    
    r <- R$offset_tick*R$events/R$offset
    DATA <- matrix(NaN, nrow = A, ncol = 3*P)
    DATA[,seq.int(1, 3*P, 3)]<-R$events
    DATA[,seq.int(2, 3*P, 3)]<-R$offset
    DATA[,seq.int(3, 3*P, 3)]<-r
    T <- DATA
    dn <- paste("Events, offset, and Rates - ", R$name)
    
  } else if (comp == "rci") {
    
    r <- R$offset_tick*R$events/R$offset
    v <- (R$offset_tick^2)*R$events/R$offset^2
    cilo <- r - 1.96*sqrt(v)
    cilo[cilo<0] <- 0
    cihi <- r + 1.96*sqrt(v)
    DATA <- matrix(NaN, nrow = A, ncol = 3*P)
    DATA[,seq.int(1, 3*P, 3)]<-r
    DATA[,seq.int(2, 3*P, 3)]<-cilo
    DATA[,seq.int(3, 3*P, 3)]<-cihi
    T <- DATA
    dn <- paste("Rates and 95% CI - ", R$name)
    
  } else {
    
  }
  
  T <- list(name = dn, DATA = T, ages = R$ages, periods = R$periods) 
  
}