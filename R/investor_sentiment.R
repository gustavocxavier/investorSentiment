# invSent ## ##################################################################
# 
# Title: Investor Sentiment and Anomalies in Brazilian Market
#
# Version: 0.0.1
#
# Description: Script to compute que Investor Sentiment Index of the brazilian
# market.                       
# 
# 0. SETTINGS
# 1. GETTING CLEANING DATA
# 2. INVESTOR SENTIMENT INDEX
# 3. CONSTRUCT PORTFOLIOS
# 

## 0. SETTINGS ## #############################################################
## Setting Parameters
## Definindo Parametros

# == Date === =================================================================
START <- as.Date("2001-01-01") # Initial Date
END   <- as.Date("2013-12-31") # Final Date



## 1. GETTING CLEANING DATA ## ################################################
## Get Data and Clean
## Carregar e limpar dados

# === Functions === ===========================================================

importaBaseCSV <- function(arquivo, doDia, ateDia,
                           formato="%d/%m/%Y", pula_linha=0, financeiras=F) {
    
    # Function to import Brazilian Data
    # Funcao para carregar dados Economatica
    
    # Importanto matriz de precos mensais
    tabela <- read.table (arquivo, header = T, sep=";", dec=",",
                          row.names=1, skip=pula_linha,
                          na.strings="-", stringsAsFactors=F)
    
    # Retirando as empresas financeiras (coluna 1109(ABCB11) a 1224)
    if (financeiras == F ) { tabela     <- tabela[c(-1109:-1224)] }
    
    # TODO: Fazer a sele��o de empresas financeiras e nao financeiras
    # automatica.
    
    # Filtrando a data em matriz mensal
    tabela <-  tabela[(as.Date(rownames(tabela), format=formato) >= doDia
                       &
                           as.Date(rownames(tabela), format=formato) <= ateDia)
                      ,]
    return(tabela)
}

createDateIndex <- function() {
    # Fun��o que cria �ndice de data
    # Criando de uma matriz mapa de datas
    matriz_indice <- data.frame(Date=seq(from=START,to=END,by="month"))
    
    matriz_indice <- cbind(matriz_indice,
                           M=as.numeric(substr(as.character(matriz_indice$Date),6,7)),
                           Y=as.numeric(substr(as.character(matriz_indice$Date),1,4)),
                           Q=as.numeric(substr(quarters(matriz_indice$Date),2,2))
    )
    matriz_indice <- cbind(matriz_indice,
                           Quarter=paste(matriz_indice$Q, "T", matriz_indice$Y, sep = ""),
                           nM = seq(1:length(matriz_indice$Date)),
                           nY = matriz_indice$Y+1-as.numeric(substr(as.character(START),1,4)),
                           nQ = sort(rep(1:ceiling(nrow(matriz_indice)/4),4))[1:nrow(matriz_indice)]
    )
    
    return(matriz_indice)
}

filter24months <- function (sample1, prices) {
    # Function to filter the stocks that have 24 months of consecutive prices
    newSample <- sample1
    for ( j in seq_len(ncol(prices)) ) {
        # Fazer essa rotina para coluna j
        for ( i in seq_len(nrow(prices)) ) {
            # Fazer essa rotina para cada linha i da coluna j
            # Verificar se a linha i est? entre START+1 e END-1
            if ( i<=12 ) {
                newSample[as.numeric(dateIndex$nY[i]),j] <- 0
            }
            else if( i>floor(nrow(dateIndex)/12)*12 ) {
                # nao faz nada
            }
            # Verificar se a linha i corresponde ao mes de junho
            else if ( as.numeric(dateIndex$M[i])==6 ) {
                # Verifica se tem preço nos 24 meses consecutivos
                if (sum(!is.na(prices[(i-12):(i+12),j])) != 25) {
                    # E atribui 0 na matriz de controle da amostra
                    newSample[as.numeric(dateIndex$nY[i]),j] <- 0
                }
            }
        }
    }
    return(newSample)
}

# === Read Data === ===========================================================

# Stock Prices
mPrices     <- importaBaseCSV("Input/mPrices.csv", START, END)

# === Initial Sample === ======================================================

# Initial Sample (1 para todos os anos que houve cotacao)
ySample0 <- importaBaseCSV("Input/ySample0.csv", START, END, formato="%Y")

dateIndex <- createDateIndex() # Generate date map matrix for the next cmd

ySample24m  <- filter24months(ySample0, mPrices) # Filter of 24 months

# Bovespa Negociability Index
mNegociabilidade <- importaBaseCSV("Input/mNegociabilidade.csv", START, END)

# Convert monthly to yearly
yNegociabilidade <- mNegociabilidade[dateIndex$M==12,]
row.names(yNegociabilidade) <- dateIndex$Y[dateIndex$M==12]

# Liquidity filter by negociability index
ySampleNegociab <- ySample0
ySampleNegociab[yNegociabilidade <= 0.01] <- 0

# Read Book Value
yBookFirm <- importaBaseCSV("Input/yBookFirm.csv", START, END, formato="%Y")

# Positive Book Value Filter
ySamplePositiveBook <- ySample0
ySamplePositiveBook[ is.na(yBookFirm) ] <- 0
ySamplePositiveBook[ yBookFirm < 0    ] <- 0

# === Final Sample === ========================================================

# Compute all the filters together
ySample <- ySample24m * ySampleNegociab * ySamplePositiveBook

## Generate Yearly Sample Control Matrix
mSample <- ySample[sort(rep(1:nrow(ySample),12)),] # repeat 12 times the values
# Add rows to the last incomplete year
mSample <- rbind(mSample, mSample[rep(nrow(mSample),
                                      nrow(mPrices)-nrow(mSample)), ])
row.names(mSample) <- row.names(mPrices) # Set name of the rows equal mPrices

# === Results of Sample === ===================================================
rowSums(ySample0)#[-1]                # Initial Sample

rowSums(ySample24m)[-1]          # Just the firms with 24 months of price
round(rowSums(ySample24m)[-1]/rowSums(ySample0)[-1],2)          # %

rowSums(ySamplePositiveBook)[-1] # Just the Positive book
round(rowSums(ySamplePositiveBook)[-1]/rowSums(ySample0)[-1],2) # %

rowSums(ySampleNegociab)[-1]     # Just the most liquid
round(rowSums(ySampleNegociab)[-1]/rowSums(ySample0)[-1],2)     # %

rowSums(ySample)#[-1]             # Final Sample
round(rowSums(ySample)/rowSums(ySample0),2)             # %
round(rowSums(ySample)[-1]/rowSums(ySample0)[-1],2)             # %

# The first year was not computed because the 24 months filter

# OK Negociability but not OK 24 months
rowSums(ySampleNegociab)[-1]-rowSums(ySample24m*ySampleNegociab)[-1]

# OK 24 months but not OK Negociability
rowSums(ySample24m)[-1]-rowSums(ySample24m*ySampleNegociab)[-1]



## 2. INVESTOR SENTIMENT INDEX ## #############################################
## 2. �ndice de Sentimento
## 2.1. Temporalidade das Proxies: Selecionar proxies que ser�o defasadas
## 2.2. �ndice de Sentimento n�o Ortogonalizado
## 2.3. �ndice de Sentimento Ortogonalizado � vari�veis macroecon�micas  

# === Read/Compute Proxies === ===============================================

mProxies   <- read.table ("Input/mProxies.csv",          # Read data
                          header = T, sep=";", dec=",",
                          row.names=1)
x <- as.Date(rownames(mProxies), format="%d/%m/%Y")      # Temporary variable
mProxies <- mProxies[(x >= START & x <= END),] ; rm(x) ; # Date filter
as.dist(round(cor(mProxies),2))                          # Correlations

# === First Step === ==========================================================
# Estimating first component of all proxies and their lags and choose the best

PCAstep1 <- prcomp(mProxies, scale=T)

chooseLAG <- function (m) {
    
    # FUNCTION TO CHOOSE THE BEST CORRELATION BETWEEN THE EACH CURRENT AND
    # LAGGED PROXIES
    # ______________________________________________________________
    # INPUT:
    #
    # m ...... Proxies Data
    #
    # ______________________________________________________________

    nproxies <- ncol(m)
    i <- 1
    delete <- 0
    for ( i in 1:(nproxies/2) ) {
        proxy <- cor(PCAstep1$x[,"PC1"],m)[i]
        proxy_lagged <- cor(PCAstep1$x[,"PC1"],m)[i+(nproxies/2)]
        if ( abs(proxy) < abs(proxy_lagged) ) { delete <- c(delete,-1*i) }
        if ( abs(proxy) > abs(proxy_lagged) ) { delete <- c(delete,-1*(i+(nproxies/2))) }
    }
    delete <- delete[-1]
    return(m[delete])
    
    # ______________________________________________________________
    # OUTPUT: data.frame/matrix just with the best proxies
    # ______________________________________________________________
}

round(cor(PCAstep1$x[,"PC1"],mProxies),2)         # The correlations
mBestProxies <- chooseLAG(mProxies);rm(chooseLAG) # Choosing LAGs...
colnames(mBestProxies)                            # Best proxies
round(cor(PCAstep1$x[,"PC1"],mBestProxies),2)     # Correlation with PC1
as.dist(round(cor(mBestProxies),2))               # Correlations between them

# === Second Step === =========================================================
# Estimating first component of the best proxies

PCAstep2 <-prcomp(mBestProxies, scale=T)

cor(PCAstep1$x[,"PC1"],PCAstep2$x[,"PC1"]) # Correlation with PC1 of the 1� step
summary(PCAstep2)                          # Proportion of Variance
PCAstep2$rotation[,"PC1"] # Not orthogonalized index (osb.: not important)

# === Third Step === ==========================================================
# Estimate orthogonilized proxies by the regression all raw proxies

# Read macroeconomics variables
mMacroeconomics   <- read.table ("Input/mMacroeconomics.csv",   header = T, 
                                 sep=";", dec=",", na.strings="-", row.names=1)

# Date Filter
x <- as.Date(rownames(mMacroeconomics), format="%d/%m/%Y")
mMacroeconomics <-  mMacroeconomics[(x >= START & x <= as.Date("2013-12-01")),]
rm(x)
                                                  # <= END

END   <- as.Date("2014-07-01") # TODO: Discover why this

# dummy SELIC igual a 1 quando a taxa cai em rela??o ao m?s anterior
dSELIC <- c(0,as.numeric(embed(mMacroeconomics$SELIC,2)[,1] <= 
                                 embed(mMacroeconomics$SELIC,2)[,2]
)
)

# dummy PIB igual a 1 quando o PIB sobe em rela??o ao m?s anterior
dPIB   <- c(0,as.numeric(embed(mMacroeconomics$PIB,2)[,1] >=
                                 embed(mMacroeconomics$PIB,2)[,2]
)
)

# Retirando a s�rie da Selic e deixando s� a do PIB
mMacroeconomics$SELIC <- NULL
# Acrescentando o dPIB e o dSELIC
mMacroeconomics <-cbind(mMacroeconomics, dPIB, dSELIC)
rm(list=c("dPIB","dSELIC"))

# Estimando Proxies Ortogonalizada
mProxiesOrtog <- mBestProxies
for ( i in 1:ncol(mProxiesOrtog)) {
        mProxiesOrtog[,i] <- lm(mBestProxies[,i] ~ data.matrix(mMacroeconomics))$residuals
}
rm(i)

# Estimando Componentes Principais da Terceira Etapa
PCAstep3 <-prcomp(mProxiesOrtog, scale=T)

# Estimando Componentes Principais da Terceira Etapa
PCAstep3 <-prcomp(mProxiesOrtog, scale=T)
# PCAstep3 <- princomp(mProxiesOrtog, scores=T, cor=T) # Metodo alternativo

# Verificando correlacao com o primeiro indice
cor(PCAstep2$x[,"PC1"],PCAstep3$x[,"PC1"])

# Percentual explicado da variancia
summary(PCAstep3)
# summary(princomp(mProxiesOrtog, scores=T, cor=T)) # Metodo alternativo

# Scree plot of eigenvalues
screeplot(PCAstep3, type="line", main="Scree Plot Sentimento Ortogonalizado")

PCAstep3$rotation[,"PC1"] * (-1) # Equacao do Indice de Sent. Ortogonalizado
Sent <- PCAstep3$x[,"PC1"]

# === Sentiment Results === ===================================================
# as.dist(round(cor(mProxies),2))                      # Verificando correla��o entre as proxies
# round(cor(PCAstep1$x[,"PC1"],mProxies),2)            # Correla��o das Proxies com 1� Componente da 1� Etapa
# round(cor(PCAstep1$x[,"PC1"],mBestProxies),2)        # Correla��o Proxies Escolhidas c/ 1� Componente da 1� Etapa
# cor(PCAstep1$x[,"PC1"],PCAstep2$x[,"PC1"]) * (-1)    # Verificando correlacao com o primeiro indice
# summary(PCAstep2)                                    # Percentual explicado da variancia
# PCAstep2$rotation[,"PC1"] * (-1)                     # Equacao do Indice de Sentimento Nao Ortogonalizado
# as.dist(round(cor(mBestProxies),2))                  # Correla��o Proxies Escolhidas
# round(cor(PCAstep2$x[,"PC1"],mBestProxies),2) * (-1) # Correla��o Proxies Escolhidas c/ 1� Componente da 2� Etapa
# cor(PCAstep2$x[,"PC1"],PCAstep3$x[,"PC1"])           # Correla��o do Indice da 3� etapa com o da 2� etapa
# summary(PCAstep3)                                    # Percentual explicado da variancia
# PCAstep3$rotation[,"PC1"] * (-1)                     # Equacao do Indice de Sentimento Ortogonalizado



## 3. CONSTRUCT PORTFOLIOS ## #################################################
## 3. Portfolios
## 3.1 Construir Carteiras
##       portfolioAssets cria_matriz_carteira - retorna dCriterio
## 3.2 Intera��o de Carteiras
##       portfolioAssetesInteracao = portfolioAssets1 x portfolioAssets2
## 3.3 Retorno das Carteiras
##       portfolioSerie - retorna ...

# === Functions === ===========================================================

portfolioRange <- function(CRITERIO, nPortfolios=5, portfolio=1) {
    
    # ______________________________________________________________
    # 
    # Retorna os valores m�ximos e m�nimos para forma��o de um portfolio
    # Cria vetor de sequencia
    x <- c(0,seq(1:nPortfolios)/nPortfolios)
    # Salvando o valor maximo e minimo
    RANGE <- quantile(CRITERIO, x[portfolio:(portfolio+1)], na.rm=T)
    # Retorna a faixa de valor do portfolio escolhido
    
    # ______________________________________________________________
    
    return(RANGE)
}

`%between%` <- function(x,rng) {
    
    # FUN��O QUE VERIFICA SE UM VALOR EST� ENTRE OS EXTREMOS DE UMA
    # S�RIE
    # ______________________________________________________________
    # INPUT:
    #
    # x ...... Valor de interesse
    # rng .... Vetor com a s�rie ou os extremos
    #
    # Sintaxe: x %between% rng
    #
    # ______________________________________________________________
    
    x <= max(rng,na.rm = TRUE) & x >= min(rng,na.rm = TRUE)
    
    # ______________________________________________________________
    # OUTPUT: Valor l�gico
    # ______________________________________________________________
}

portfolioAssets <- function(CRITERIO, nPortfolios=5, portfolio=1) {
        
        # CRITERIO .... Vetor de criterio
        # nPortfolios . N�mero de portfolios
        # iPortfolio .. Portfolio desejado
        
        # Salvando faixa de valor do portfolio escolhido
        RANGE <- portfolioRange(CRITERIO, nPortfolios, portfolio)
        
        # Cirando vetor de ativos que participam da carteira
        dCriterio <- CRITERIO %between% RANGE
        dCriterio[is.na(dCriterio)] <- FALSE
        return(as.numeric(dCriterio))
}

portfolioAssets2 <- function(CRITERIO, nPortfolios=5, portfolio=1) {
        for (i in 1:nrow(CRITERIO)) {
                # Salvando faixa de valor do portfolio escolhido
                #RANGE <- portfolioRange(CRITERIO[i,], nPortfolios, portfolio)
                
                # Cirando vetor de ativos que participam da carteira
                dCriterioVector <- portfolioAssets(CRITERIO[i,], nPortfolios, portfolio)
                #dCriterio <- CRITERIO %between% RANGE
                #dCriterio[is.na(dCriterio)] <- FALSE 
                
                # ADICIONAR A UM DATA FRAME
                if ( !exists("dCriterioMatrix") ) {
                        # SE FOR A TABELA NAO EXISTE, CRIA
                        dCriterioMatrix <- CRITERIO[1,]
                        dCriterioMatrix[!is.na(dCriterioMatrix)] <- NA
                        dCriterioMatrix <- dCriterioVector
                } else { # SE EXISTE, APENAS ADICIONAR LINHAS
                        dCriterioMatrix <- rbind(dCriterioMatrix,
                                                 dCriterioVector)
                }
        }
        dCriterioMatrix[is.na(dCriterioMatrix)] <- 0
        row.names(dCriterioMatrix) <- row.names(CRITERIO)
        # RETORNAR O DATA FRAME
        return(dCriterioMatrix)
}

portfolioSerie <- function (RETURN, MV, PortfolioAssets) {
        
        # INPUT
        # ______________________________________________________________
        #
        # RETURN ...... Matriz de Retornos
        # MV .......... Matriz com os Valores de Mercado
        # PortfolioAssets ... Matriz de ativos pertecentes ao Portfolio
        # ______________________________________________________________
        
        for (i in 1:nrow(RETURN)) {
                
                # Cria vetor que diz qual ativo pertence � carteira
                ASSETS <- as.logical(PortfolioAssets[dateIndex$nY[i],])
                
                # Valor de Mercado total dos ativos da carteira
                marketVALUE  <- sum(MV[i,ASSETS], na.rm=T)
                
                # Quantidade de ativos na carteira
                nA  <- sum(as.numeric(ASSETS))
                
                # Media igualmente ponderada do retorno dos ativos da carteira
                rEW <- mean(RETURN[i,ASSETS], na.rm=T)
                
                # Media ponderada pelo valor do retorno dos ativos da carteira
                rWV <- sum (RETURN[i,ASSETS] * MV[i,ASSETS] / marketVALUE, na.rm=T)
                
                # xC
                if ( !exists("pSerie") ) {
                        # SE FOR A TABELA NAO EXISTE, CRIA
                        pSerie <- data.frame(rEW=rEW,
                                             rWV=rWV,
                                             MV=marketVALUE,
                                             nA=nA)
                } else { # SE EXISTE, APENAS ADICIONAR LINHAS
                        pSerie <- rbind(pSerie,c(rEW,
                                                 rWV,
                                                 marketVALUE,
                                                 nA))
                }
        }
        
        # ______________________________________________________________
        #
        #  OUTPUT
        # ______________________________________________________________
        #
        # rEW ... S�rie de retornos igualmente ponderado
        # rWV ... S�rie de retornos ponderado pelo valor
        # MV .... Valor de Mercado da carteira no per�odo
        # nA .... N�mero de ativos da carteira no per�odo
        # xC .... Valor m�dio da caracter�stica de forma��o da carteira
        # ______________________________________________________________
        
        row.names(pSerie) <- row.names(RETURN)
        return(pSerie)
        
        
}

# === Returns === =============================================================

# Compute Returns
tempPrices  <- importaBaseCSV("Input/mPrices.csv", (START-31), END)
mReturns    <- as.data.frame(diff(log(as.matrix(mPrices)))) ; rm(tempPrices)

# Read Market Value
mMarketValue     <- importaBaseCSV("Input/mMarketValue.csv",
                                   START, END, pula_linha=1)

# Convert monthly data to yearly
yMarketValue <- mMarketValue[dateIndex$M==12,]

yMarketValue[ySample==0]      <- NA
yMarketValue[yMarketValue==0] <- NA
yBookFirm[ySample==0]         <- NA

# Compute Book-to-market
yBM <- yBookFirm / yMarketValue
length(yBookFirm[yBookFirm==0])
yBM[yMarketValue==0] <- NA
yBM[yBM==+Inf]
sum(yBookFirm==0, na.rm=T)
sum(yMarketValue==0, na.rm=T)
sum(yBM<=-Inf, na.rm=T)

head(which(yBookFirm!=0, arr.ind=T))
yBookFirm[,1:2]

##Teste Range
portfolioRange(yMarketValue[2,],2,1)
portfolioRange(yBM,3,1) # Verificar o -Inf e o +Inf

# szS szB bmH bmN bmL SH SN SL BN BL
AssetsSize_S <- portfolioAssets2(yMarketValue,2,1)  # Small
AssetsSize_B <- portfolioAssets2(yMarketValue,2,2)  # Big   

AssetsBM_H <- portfolioAssets2(yBM,3,1)             # Value (High BM)
AssetsBM_N <- portfolioAssets2(yBM,3,2)             # Neutral
AssetsBM_L <- portfolioAssets2(yBM,3,3)             # Growth (Low BM)

AssetsSH <- AssetsSize_S * AssetsBM_H # Small Value (High BM)
AssetsSN <- AssetsSize_S * AssetsBM_N # Small Neutral
AssetsSL <- AssetsSize_S * AssetsBM_L # Small Growth (Low BM)
AssetsBH <- AssetsSize_B * AssetsBM_H # Big Value (High BM)
AssetsBN <- AssetsSize_B * AssetsBM_N # Big Neutral
AssetsBL <- AssetsSize_B * AssetsBM_L # Big Growth (Low BM)

AssetsSH <- apply(AssetsSH, 1, function(x) as.logical(x) ) # Small Neutral
AssetsSN <- apply(AssetsSN, 2, function(x) as.logical(x) ) # Small Neutral
AssetsSL <- apply(AssetsSL, 2, function(x) as.logical(x) ) # Small Growth (Low BM)
AssetsBH <- apply(AssetsBH, 2, function(x) as.logical(x) ) # Big Value (High BM)
AssetsBN <- apply(AssetsBN, 2, function(x) as.logical(x) ) # Big Neutral
AssetsBL <- apply(AssetsBL, 2, function(x) as.logical(x) ) # Big Growth (Low BM)
AssetsSH[1:5,1:5]

rownames(AssetsSH) <- rownames(yBM)
rownames(AssetsSN) <- rownames(yBM)
rownames(AssetsSL) <- rownames(yBM)
rownames(AssetsBH) <- rownames(yBM)
rownames(AssetsBN) <- rownames(yBM)
rownames(AssetsBL) <- rownames(yBM)

# ...........................

interactPortfolios <- function (x, y) {
        # Criando tabela
        tabela <- x
        for (i in 1:nrow(tabela)) {
                tabela[i,] <- as.logical(x[i,] * y[i,])
        }
        return(tabela)
}

C <- A[c(1,2,1,3,5),c(1,2,3,4,5,1)]
B
D <- B*C
apply(D, 2, function(x) as.logical(x) )

# ........ Procurar no stack overflow como transformar data.frame 1 o em logico

# HML = 1/2 (Small Value + Big Value) - 1/2 (Small Growth + Big Growth)
FactorHML <- 1/2*(AssetsSH)

# SMB = 1/3 (Small Value + Small Neutral + Small Growth)
#       - 1/3 (Big Value + Big Neutral + Big Growth)
PortfolioSMB <- 
        PortfolioHML
debug(portfolioSerie)
serieSmallValue <- portfolioSerie(mReturns, mMarketValue,AssetsSH)
warnings()
head(AssetsSH[,1:5])
head(mReturns[,1:5])
tail(mReturns[,1:5])
tail(AssetsSH[,1:5])

serieSmallValue <- portfolioSerie(mReturns, mMarketValue,AssetsSH)

seriePortBM1 <- portfolioSerie(mReturns, mMarketValue, portfolioAssets2(yBM,5,1))

# TESTE INDICE
LAG <- 12
summary(lm(seriePortBM1$rWV[(1+LAG):156]  ~ PCAstep3$x[,"PC1"][1:(156-LAG)]))


length(seriePortBM1$rWV[13:156])
length(PCAstep3$x[,"PC1"][1:144])


# _____________________________________________________________________________
# TESTE UTILIZANDO DADOS REAIS

nAtivos <- 1108

precins  <- mPrices[12:36,1:nAtivos]
retornin <- diff(log(as.matrix(precins)))
valorzin <- mMarketValue[13:36,1:nAtivos]
criterin <- yBookFirm[1:2,1:nAtivos]
criterin <- yBookFirm[1:2,1:nAtivos] / valorzin[c(12,24),]

#portfolioAssets2(criterin,3,1)
#portfolioAssets2(criterin,3,3)
#portfolioSerie(retornin, valorzin, portfolioAssets2(criterin,5,1))

#rm(list=c("precins", "retornin", "criterin", "valorzin", "nAtivos"))

# ..............................................................................
# 
# ..............................................................................

# _____________________________________________________________________________
## TESTE EM VETORES
#
#portfolioRange(yNegociabilidade[1,],5,5)
#portfolioAssets(yNegociabilidade[1,],5,1)
# _____________________________________________________________________________
## TESTE EM MATRIZ
## SIMULANDO VALORES
#retornin <- matrix(rnorm((12*3*5),0,0.3), ncol=5, nrow=(12*3))
#criterin <- matrix(round( rnorm((3*5),10,5) ,0), ncol=5, nrow=3)
#valorzin <- matrix(round(rnorm((12*3*5),100,50),0), ncol=5, nrow=(12*3))
#
#portfolioSerie(retornin,
#               valorzin,
#               portfolioAssets2(criterin,5,1)
#)
#rm(list=c("retornin", "criterin", "valorzin"))
# ______________________________________________________________________________
# TESTE UTILIZANDO A FUN��O APPLY
#
#wPortfolio <- t(         apply(valorzin,
#                               MARGIN=1, function (x) (x/sum(x, na.rm=T)) ) )
#rPortfolio <- as.matrix( apply(retornin*wPortfolio,
#                               MARGIN=1, sum, na.rm=T                     ) )
#
#

## PRICING MODEL ## ###########################################################
## 3. Fatores de Risco
## 3.1 Fator de Mercado
## 3.2 Construir Carteiras
## 3.3 Interagir Carteiras
## 3.4 Retorno das Carteiras Ponderado pelo Valor


## 4. INVESTOR SENTIMENT AND ANOMALIES ## #####################################
## Sentimento do Investidor e Anomalias
## 4.1. An�lise das M�dias ap�s per�odos de Sentimento Alto e Baixo
## 4.2. Modelos Econom�tricos
## 4.1 Extremos e sentimento defasado
## 4.2 Extremos, sentimeto defasado e fatores de risco
## 4.3 Extremos, dummys

# === An�lise de M�dias === ===================================================

# === Predictive Regressions === ==============================================

# Sent.Long.Beta   <- lm(Long.Beta  ~ SENT[_n-1]+MKT+SMB+HML+MOM+LIQ)
# Sent.Short.Beta  <- lm(Short.Beta ~ SENT[_n-1]+MKT+SMB+HML+MOM+LIQ)
# Dummy.Long.Beta  <- lm(Long.Beta  ~ dH+dL+MKT+SMB+HML+MOM+LIQ)
# Dummy.Short.Beta <- lm(Short.Beta ~ dH+dL+MKT+SMB+HML+MOM+LIQ)
# 
# Sent.Long.Size   <- lm(Long.Size  ~ SENT[_n-1]+MKT+SMB+HML+MOM+LIQ)
# Sent.Short.Size  <- lm(Short.Size ~ SENT[_n-1]+MKT+SMB+HML+MOM+LIQ)
# Dummy.Long.Size  <- lm(Long.Size  ~ dH+dL+MKT+SMB+HML+MOM+LIQ)
# Dummy.Short.Size <- lm(Short.Size ~ dH+dL+MKT+SMB+HML+MOM+LIQ)
# 
# Sent.Long.BM   <- lm(Long.BM  ~ SENT[_n-1]+MKT+SMB+HML+MOM+LIQ)
# Sent.Short.BM  <- lm(Short.BM ~ SENT[_n-1]+MKT+SMB+HML+MOM+LIQ)
# Dummy.Long.BM  <- lm(Long.BM  ~ dH+dL+MKT+SMB+HML+MOM+LIQ)
# Dummy.Short.BM <- lm(Short.BM ~ dH+dL+MKT+SMB+HML+MOM+LIQ)
# 
# Sent.Long.Liquidity   <- lm(Long.Liquidity  ~ SENT[_n-1]+MKT+SMB+HML+MOM+LIQ)
# Sent.Short.Liquidity  <- lm(Short.Liquidity ~ SENT[_n-1]+MKT+SMB+HML+MOM+LIQ)
# Dummy.Long.Liquidity  <- lm(Long.Liquidity  ~ dH+dL+MKT+SMB+HML+MOM+LIQ)
# Dummy.Short.Liquidity <- lm(Short.Liquidity ~ dH+dL+MKT+SMB+HML+MOM+LIQ)