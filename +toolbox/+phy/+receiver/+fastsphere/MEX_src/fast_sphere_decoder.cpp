/*
 * fast_sphere_decoder.cpp
 *
 * Soft-output MEX with MMSE-SQRD layer ordering.
 *
 * Key improvement over _listsoft.cpp:
 *   Before QR, the Nt complex layers (= 2*Nt real columns) are permuted so
 *   the WEAKEST layer (lowest MMSE SINR = ||h_k||^2/N0) is at the LEAF
 *   (depth 0, enumerated last) and the STRONGEST is at the ROOT
 *   (depth nRealTx-1, enumerated first).
 *   I/Q pairs are kept together.  LLR output is de-permuted to original order.
 *
 * Interface:
 *   [llr, nVisitedNodes] = ...(H,y,moduTypes,outType,N0,nCand,maxList,useQrAugmentation)
 */

#include "mex.h"
#include "matrix.h"
#include <cmath>
#include <cstring>
#include <cctype>
#include <algorithm>
#include <limits>
#include <cstdint>

static const int MAX_NT=8, MAX_REAL_TX=16, MAX_BITS=80;
static const int MAX_PAM=32, MAX_KAXIS=5, MAX_NR=32, MAX_LIST=512;
static const int MAX_QR_ROWS=2*MAX_NR+MAX_REAL_TX;

static inline bool strieq(const char* a,const char* b){
    while(*a&&*b){if(tolower((unsigned char)*a)!=tolower((unsigned char)*b))return false;++a;++b;}
    return *a==*b;
}

struct PamAxis{int nPAM,mBits;double levels[MAX_PAM];uint8_t bits[MAX_PAM][MAX_KAXIS];uint8_t bitsQ[MAX_PAM][MAX_KAXIS];};

static inline int nearestPamIndex(double q,const double* levels,int nPAM){
    int best=0; double bestAbs=fabs(q-levels[0]);
    for(int p=1;p<nPAM;++p){const double a=fabs(q-levels[p]); if(a<bestAbs){bestAbs=a; best=p;}}
    return best;
}

static int expandLevelCandidates(double rhs,double Rdd,const PamAxis& ax,int nCand,int* candOut,double* metricOut){
    const int M=ax.nPAM;
    if(M<=1){
        double tc[MAX_PAM]; int ord[MAX_PAM];
        for(int p=0;p<M;++p){const double res=rhs-Rdd*ax.levels[p]; tc[p]=res*res; ord[p]=p;}
        std::sort(ord,ord+M,[&](int a,int b){return tc[a]<tc[b];});
        const int nTry=(nCand<M)?nCand:M;
        for(int i=0;i<nTry;++i){candOut[i]=ord[i]; metricOut[i]=tc[ord[i]];}
        return nTry;
    }

    const double q=(fabs(Rdd)>1e-12)?(rhs/Rdd):0.0;
    const int center=nearestPamIndex(q,ax.levels,M);
    int order[MAX_PAM]; double metric[MAX_PAM]; int ptr=0;
    order[ptr]=center;
    const double s0=ax.levels[center];
    double d0=(rhs-Rdd*s0)*(rhs-Rdd*s0);
    metric[ptr]=d0;
    ++ptr;

    int left=center-1,right=center+1;
    while(left>=0 || right<M){
        if(right<M){const double s=ax.levels[right]; const double d=(rhs-Rdd*s)*(rhs-Rdd*s); order[ptr]=right; metric[ptr]=d; ++ptr; ++right;}
        if(left>=0){const double s=ax.levels[left]; const double d=(rhs-Rdd*s)*(rhs-Rdd*s); order[ptr]=left; metric[ptr]=d; ++ptr; --left;}
    }

    const int nTry=(nCand<M)?nCand:M;
    for(int i=0;i<nTry;++i){candOut[i]=order[i]; metricOut[i]=metric[i];}
    return nTry;
}

static void buildPamAxis(const char* modu,PamAxis& ax){
    int M,scaleInt;
    if(strieq(modu,"qpsk")){M=4;scaleInt=2;}
    else if(strieq(modu,"16qam")){M=16;scaleInt=10;}
    else if(strieq(modu,"64qam")){M=64;scaleInt=42;}
    else if(strieq(modu,"256qam")){M=256;scaleInt=170;}
    else if(strieq(modu,"1024qam")){M=1024;scaleInt=682;}
    else mexErrMsgIdAndTxt("SD:modu","Unsupported modulation.");
    const int K=(M==4)?2:(M==16)?4:(M==64)?6:(M==256)?8:10,m=K/2,nP=1<<m;
    const double sqrtScale=sqrt((double)scaleInt);
    ax.nPAM=nP;ax.mBits=m;
    double rawL[MAX_PAM];uint8_t rawB[MAX_PAM][MAX_KAXIS];int found=0;
    for(int idx=0;idx<M&&found<nP;++idx){
        int b[10]={0};for(int k=0;k<K;++k)b[k]=(idx>>(K-1-k))&1;
        double re;
        switch(M){case 4:re=(1-2*b[0]);break;case 16:re=(1-2*b[0])*(2-(1-2*b[2]));break;
            case 64:re=(1-2*b[0])*(4-(1-2*b[2])*(2-(1-2*b[4])));break;
            case 256:re=(1-2*b[0])*(8-(1-2*b[2])*(4-(1-2*b[4])*(2-(1-2*b[6]))));break;
            default:re=(1-2*b[0])*(16-(1-2*b[2])*(8-(1-2*b[4])*(4-(1-2*b[6])*(2-(1-2*b[8])))));break;}
        re/=sqrtScale;
        bool dup=false;for(int p=0;p<found;++p)if(fabs(rawL[p]-re)<1e-12){dup=true;break;}
        if(dup)continue;rawL[found]=re;for(int k=0;k<m;++k)rawB[found][k]=(uint8_t)b[2*k];++found;
    }
    int ord[MAX_PAM];for(int p=0;p<nP;++p)ord[p]=p;
    std::sort(ord,ord+nP,[&](int a,int b){return rawL[a]<rawL[b];});
    /* Build I-axis bits table (bits[p][k] = b[2k]) and Q-axis bits table (bitsQ[p][k] = b[2k+1]).
     * I and Q axes share the same PAM levels but have independent Gray-code bit labels.
     * I-axis: real part = f(b[0],b[2],b[4],...) — bits stored in rawB above.
     * Q-axis: imag part = f(b[1],b[3],b[5],...) — same level formula but using odd bits.
     * Key: for each PAM level value L, find the symbol where the Q-axis formula gives L
     *      (i.e. b[1],b[3],b[5] produce L), then store those odd bits as rawBQ[level_idx]. */
    uint8_t rawBQ[MAX_PAM][MAX_KAXIS]={};
    for(int idx2=0;idx2<M;++idx2){
        int b2[10]={0};for(int k=0;k<K;++k)b2[k]=(idx2>>(K-1-k))&1;
        /* Compute Q-axis level using ODD-indexed bits b[1],b[3],b[5],... */
        double qLev;
        switch(M){
            case 4:  qLev=(1-2*b2[1]);break;
            case 16: qLev=(1-2*b2[1])*(2-(1-2*b2[3]));break;
            case 64: qLev=(1-2*b2[1])*(4-(1-2*b2[3])*(2-(1-2*b2[5])));break;
            case 256:qLev=(1-2*b2[1])*(8-(1-2*b2[3])*(4-(1-2*b2[5])*(2-(1-2*b2[7]))));break;
            default: qLev=(1-2*b2[1])*(16-(1-2*b2[3])*(8-(1-2*b2[5])*(4-(1-2*b2[7])*(2-(1-2*b2[9])))));break;
        }
        qLev/=sqrtScale;
        /* Only store when the I-axis level (re) also matches this symbol's I bits,
         * so we pick the canonical symbol where b[0]=b[2]=b[4]=0 (or any fixed I pattern).
         * Actually simpler: just use the Q-axis level to find the PAM slot directly.
         * Since Q-axis bits b[1],b[3],b[5] uniquely determine qLev, each qLev appears
         * exactly nP times (once per I-axis pattern). We only need to store once per slot. */
        for(int p=0;p<nP;++p){
            if(fabs(rawL[p]-qLev)<1e-12){
                /* rawBQ[p] may be written multiple times but always with the same Q bits
                 * because qLev is uniquely determined by b[1],b[3],b[5] regardless of b[0],b[2],b[4]. */
                for(int k=0;k<m;++k) rawBQ[p][k]=(uint8_t)b2[2*k+1];
                break;
            }
        }
    }
    for(int p=0;p<nP;++p){
        ax.levels[p]=rawL[ord[p]];
        for(int k=0;k<m;++k) ax.bits[p][k] =rawB [ord[p]][k];   /* I-axis bits */
        for(int k=0;k<m;++k) ax.bitsQ[p][k]=rawBQ[ord[p]][k];  /* Q-axis bits */
    }
}

static void realThinQR(const double* A,int nRows,int nCols,double* Q,double* R){
    double V[MAX_QR_ROWS*MAX_REAL_TX];
    memcpy(V,A,sizeof(double)*(size_t)nRows*(size_t)nCols);
    memset(R,0,sizeof(double)*(size_t)nCols*(size_t)nCols);
    for(int k=0;k<nCols;++k){
        for(int j=0;j<k;++j){
            double rjk=0.0;for(int i=0;i<nRows;++i)rjk+=Q[i+j*nRows]*A[i+k*nRows];
            R[j+k*nCols]=rjk;for(int i=0;i<nRows;++i)V[i+k*nRows]-=rjk*Q[i+j*nRows];
        }
        double n2=0.0;for(int i=0;i<nRows;++i)n2+=V[i+k*nRows]*V[i+k*nRows];
        const double nrm=sqrt(n2);R[k+k*nCols]=nrm;
        const double inv=(nrm>1e-14)?1.0/nrm:0.0;
        for(int i=0;i<nRows;++i)Q[i+k*nRows]=V[i+k*nRows]*inv;
    }
}

static double mmseInit(const double* HR,const double* yR,int nRows,int nDim,
                       const PamAxis* pam,double N0,int* idxInit,double* xInit){
    /* Use a regularised noise level for the matrix inversion to ensure
     * numerical stability at very low N0 (noisefree sanity checks). */
    const double N0reg = (N0 < 1e-6) ? 1e-6 : N0;
    double A[MAX_REAL_TX*MAX_REAL_TX]={0.0},b[MAX_REAL_TX]={0.0};
    for(int c=0;c<nDim;++c){
        for(int r=0;r<nDim;++r){double s=0.0;for(int i=0;i<nRows;++i)s+=HR[i+r*nRows]*HR[i+c*nRows];A[r+c*nDim]=s;}
        A[c+c*nDim]+=N0reg;double s=0.0;for(int i=0;i<nRows;++i)s+=HR[i+c*nRows]*yR[i];b[c]=s;
    }
    double L[MAX_REAL_TX*MAX_REAL_TX]={0.0};
    for(int i=0;i<nDim;++i){
        for(int j=0;j<=i;++j){
            double s=A[i+j*nDim];for(int k=0;k<j;++k)s-=L[i+k*nDim]*L[j+k*nDim];
            if(i==j)L[i+i*nDim]=(s>0.0)?sqrt(s):1e-14;else L[i+j*nDim]=s/L[j+j*nDim];
        }
    }
    double z[MAX_REAL_TX]={0.0};
    for(int i=0;i<nDim;++i){double s=b[i];for(int k=0;k<i;++k)s-=L[i+k*nDim]*z[k];z[i]=s/L[i+i*nDim];}
    double xLin[MAX_REAL_TX]={0.0};
    for(int i=nDim-1;i>=0;--i){double s=z[i];for(int k=i+1;k<nDim;++k)s-=L[k+i*nDim]*xLin[k];xLin[i]=s/L[i+i*nDim];}
    for(int d=0;d<nDim;++d){
        const PamAxis& ax=pam[d/2];int bestIdx=0;double bestDist=std::numeric_limits<double>::infinity();
        for(int p=0;p<ax.nPAM;++p){const double diff=xLin[d]-ax.levels[p];const double dist=diff*diff;if(dist<bestDist){bestDist=dist;bestIdx=p;}}
        idxInit[d]=bestIdx;xInit[d]=ax.levels[bestIdx];
    }
    double eucl=0.0;
    for(int i=0;i<nRows;++i){double res=yR[i];for(int d=0;d<nDim;++d)res-=HR[i+d*nRows]*xInit[d];eucl+=res*res;}
    return eucl;
}

struct CandEntry{double ped;int idx[MAX_REAL_TX];};

void mexFunction(int nlhs,mxArray* plhs[],int nrhs,const mxArray* prhs[]){
    if(nrhs<4||nrhs>8)mexErrMsgIdAndTxt("SD:nrhs","Wrong number of inputs.");
    if(nlhs>3)mexErrMsgIdAndTxt("SD:nlhs","Too many outputs (max 3: llr, nVisited, debugStruct).");
    const int Nr=(int)mxGetM(prhs[0]),Nt=(int)mxGetN(prhs[0]);
    if(Nt>MAX_NT||Nr>MAX_NR)mexErrMsgIdAndTxt("SD:size","Dim exceeds limit.");
    if((int)mxGetM(prhs[1])!=Nr||(int)mxGetN(prhs[1])!=1)mexErrMsgIdAndTxt("SD:size","y must be Nr x 1.");
    if(!mxIsCell(prhs[2])||(int)mxGetNumberOfElements(prhs[2])!=Nt)mexErrMsgIdAndTxt("SD:modu","moduTypes must be Nt-cell.");
    char outTypeBuf[8];mxGetString(prhs[3],outTypeBuf,sizeof(outTypeBuf));
    const bool isSoft=strieq(outTypeBuf,"soft");
    double N0=(nrhs>=5&&!mxIsEmpty(prhs[4]))?mxGetScalar(prhs[4]):1.0;
    int nCandPerLevel=(nrhs>=6&&!mxIsEmpty(prhs[5]))?(int)mxGetScalar(prhs[5]):4;
    int maxList=(nrhs>=7&&!mxIsEmpty(prhs[6]))?(int)mxGetScalar(prhs[6]):64;
    bool useQrAugmentation=true;
    if(nrhs>=8&&!mxIsEmpty(prhs[7])){
        if(mxGetNumberOfElements(prhs[7])!=1||(!mxIsLogical(prhs[7])&&!mxIsNumeric(prhs[7])))
            mexErrMsgIdAndTxt("SD:qrAugmentation","useQrAugmentation must be a scalar logical or numeric value.");
        useQrAugmentation=mxGetScalar(prhs[7])!=0.0;
    }
    if(N0<1e-15)N0=1e-15;
    if(nCandPerLevel<1)nCandPerLevel=1;if(nCandPerLevel>MAX_PAM)nCandPerLevel=MAX_PAM;
    if(maxList<2)maxList=2;if(maxList>MAX_LIST)maxList=MAX_LIST;

    /* PAM axes and bit offsets — original layer order */
    PamAxis pamOrig[MAX_NT];int bitOffsOrig[MAX_NT];int nOutBits=0;
    for(int i=0;i<Nt;++i){
        char* ms=mxArrayToString(mxGetCell(prhs[2],i));
        buildPamAxis(ms,pamOrig[i]);mxFree(ms);
        bitOffsOrig[i]=nOutBits;nOutBits+=2*pamOrig[i].mBits;
    }
    const int nRealTx=2*Nt,nRealRx=2*Nr;

    /* Build HR_orig */
    double HR_orig[MAX_NR*2*MAX_REAL_TX];
    const double* Hre=mxGetPr(prhs[0]);const double* Him=mxGetPi(prhs[0]);
    for(int tx=0;tx<Nt;++tx){
        const int cI=2*tx,cQ=2*tx+1;
        for(int r=0;r<Nr;++r){
            const double re=Hre[r+tx*Nr],im=Him?Him[r+tx*Nr]:0.0;
            HR_orig[r+cI*nRealRx]=re;HR_orig[r+Nr+cI*nRealRx]=im;
            HR_orig[r+cQ*nRealRx]=-im;HR_orig[r+Nr+cQ*nRealRx]=re;
        }
    }
    double yR[MAX_NR*2];
    const double* yr=mxGetPr(prhs[1]);const double* yi=mxGetPi(prhs[1]);
    for(int r=0;r<Nr;++r){yR[r]=yr[r];yR[r+Nr]=yi?yi[r]:0.0;}

    /* ---- MMSE-SQRD: sort layers by SINR = ||h_k||^2/N0 ascending ---- */
    double sinr[MAX_NT];
    for(int tx=0;tx<Nt;++tx){
        double n2=0.0;
        for(int r=0;r<nRealRx;++r){const double v=HR_orig[r+(2*tx)*nRealRx];n2+=v*v;}
        sinr[tx]=n2/N0;
    }
    int layerPerm[MAX_NT];for(int i=0;i<Nt;++i)layerPerm[i]=i;
    std::sort(layerPerm,layerPerm+Nt,[&](int a,int b){return sinr[a]<sinr[b];});
    int fwdPerm[MAX_NT];for(int pk=0;pk<Nt;++pk)fwdPerm[layerPerm[pk]]=pk;

    /* Build permuted HR, pamPerm, bitOffsPerm */
    double HR[MAX_NR*2*MAX_REAL_TX];
    PamAxis pamPerm[MAX_NT];int bitOffsPerm[MAX_NT];
    for(int pk=0;pk<Nt;++pk){
        const int ok=layerPerm[pk];pamPerm[pk]=pamOrig[ok];
        const int cIs=2*ok,cQs=2*ok+1,cId=2*pk,cQd=2*pk+1;
        for(int r=0;r<nRealRx;++r){HR[r+cId*nRealRx]=HR_orig[r+cIs*nRealRx];HR[r+cQd*nRealRx]=HR_orig[r+cQs*nRealRx];}
    }
    {int off=0;for(int pk=0;pk<Nt;++pk){bitOffsPerm[pk]=off;off+=2*pamPerm[pk].mBits;}}

    /* QR on the optionally augmented permuted system */
    const int qrRows=nRealRx+(useQrAugmentation?nRealTx:0);
    double HQR[MAX_QR_ROWS*MAX_REAL_TX],yQR[MAX_QR_ROWS];
    for(int c=0;c<nRealTx;++c)
        memcpy(HQR+c*qrRows,HR+c*nRealRx,sizeof(double)*(size_t)nRealRx);
    memcpy(yQR,yR,sizeof(double)*(size_t)nRealRx);
    if(useQrAugmentation){
        const double sqrtN0=sqrt(N0);
        for(int r=0;r<nRealTx;++r){
            for(int c=0;c<nRealTx;++c)HQR[nRealRx+r+c*qrRows]=(r==c)?sqrtN0:0.0;
            yQR[nRealRx+r]=0.0;
        }
    }
    double Q[MAX_QR_ROWS*MAX_REAL_TX],R[MAX_REAL_TX*MAX_REAL_TX];
    realThinQR(HQR,qrRows,nRealTx,Q,R);
    double Qy[MAX_REAL_TX];
    for(int c=0;c<nRealTx;++c){double s=0.0;for(int r=0;r<qrRows;++r)s+=Q[r+c*qrRows]*yQR[r];Qy[c]=s;}

    auto fullMetric=[&](const int* idx)->double{
        double metric=0.0;
        for(int d=nRealTx-1;d>=0;--d){
            double rhs=Qy[d];
            for(int j=d+1;j<nRealTx;++j)rhs-=R[d+j*nRealTx]*pamPerm[j/2].levels[idx[j]];
            const double x=pamPerm[d/2].levels[idx[d]],res=rhs-R[d+d*nRealTx]*x;
            metric+=res*res-(useQrAugmentation?N0*x*x:0.0);
        }
        return metric;
    };

    /* MMSE init */
    int idxInit[MAX_REAL_TX];double xInit[MAX_REAL_TX];
    mmseInit(HR,yR,nRealRx,nRealTx,pamPerm,N0,idxInit,xInit);
    double lambdaML=fullMetric(idxInit);
    int bestIdx[MAX_REAL_TX];for(int d=0;d<nRealTx;++d)bestIdx[d]=idxInit[d];

    /* Candidate list */
    CandEntry list[MAX_LIST];int listCount=0;
    double worstListPed=std::numeric_limits<double>::infinity();int worstListIdx=-1;
    int pathIdx[MAX_REAL_TX];double pathX[MAX_REAL_TX],augPedStack[MAX_REAL_TX],assignedSqStack[MAX_REAL_TX];
    int candList[MAX_REAL_TX][MAX_PAM],candCount[MAX_REAL_TX],candPos[MAX_REAL_TX];
    int nVisitedNodes=0;
    double maxUnassignedSq[MAX_REAL_TX]={0.0};
    if(useQrAugmentation){
        for(int d=1;d<nRealTx;++d){
            const PamAxis& ax=pamPerm[(d-1)/2];
            double maxSq=0.0;
            for(int p=0;p<ax.nPAM;++p)maxSq=std::max(maxSq,ax.levels[p]*ax.levels[p]);
            maxUnassignedSq[d]=maxUnassignedSq[d-1]+maxSq;
        }
    }

    auto maybeAddList=[&](double ped){
        if(listCount<maxList){
            list[listCount].ped=ped;for(int d=0;d<nRealTx;++d)list[listCount].idx[d]=pathIdx[d];++listCount;
            if(ped>worstListPed||worstListIdx<0){worstListPed=ped;worstListIdx=listCount-1;}
            else if(listCount==1){worstListPed=ped;worstListIdx=0;}
            if(listCount==maxList){worstListPed=list[0].ped;worstListIdx=0;for(int i=1;i<listCount;++i)if(list[i].ped>worstListPed){worstListPed=list[i].ped;worstListIdx=i;}}
        }else if(ped<worstListPed){
            list[worstListIdx].ped=ped;for(int d=0;d<nRealTx;++d)list[worstListIdx].idx[d]=pathIdx[d];
            worstListPed=list[0].ped;worstListIdx=0;for(int i=1;i<listCount;++i)if(list[i].ped>worstListPed){worstListPed=list[i].ped;worstListIdx=i;}
        }
    };
    auto initLevel=[&](int d)->double{
        const PamAxis& ax=pamPerm[d/2];const double Rdd=R[d+d*nRealTx];
        double rhs=Qy[d];for(int j=d+1;j<nRealTx;++j)rhs-=R[d+j*nRealTx]*pathX[j];
        double metricList[MAX_PAM];
        const int nTry=expandLevelCandidates(rhs,Rdd,ax,nCandPerLevel,candList[d],metricList);
        candCount[d]=nTry; candPos[d]=0;
        const int best=candList[d][0];pathIdx[d]=best;pathX[d]=ax.levels[best];
        return metricList[0];
    };
    auto nextCand=[&](int d)->bool{
        ++candPos[d];if(candPos[d]>=candCount[d])return false;
        const int idx=candList[d][candPos[d]];pathIdx[d]=idx;pathX[d]=pamPerm[d/2].levels[idx];return true;
    };

    int depth=nRealTx-1;augPedStack[depth]=initLevel(depth);assignedSqStack[depth]=pathX[depth]*pathX[depth];
    while(true){
        const double augPedHere=augPedStack[depth];
        const double correctedLowerBound=augPedHere-(useQrAugmentation?N0*(assignedSqStack[depth]+maxUnassignedSq[depth]):0.0);
        if(depth==0){
            const double pedHere=fullMetric(pathIdx);
            ++nVisitedNodes;maybeAddList(pedHere);
            if(pedHere<lambdaML){lambdaML=pedHere;for(int d=0;d<nRealTx;++d)bestIdx[d]=pathIdx[d];}
            goto advance;
        }
        if(correctedLowerBound<lambdaML||listCount<maxList||correctedLowerBound<worstListPed){
            --depth;augPedStack[depth]=augPedStack[depth+1]+initLevel(depth);
            assignedSqStack[depth]=assignedSqStack[depth+1]+pathX[depth]*pathX[depth];continue;
        }
advance:
        while(true){
            if(nextCand(depth)){
                double rhs=Qy[depth];for(int j=depth+1;j<nRealTx;++j)rhs-=R[depth+j*nRealTx]*pathX[j];
                const double Rdd=R[depth+depth*nRealTx],res=rhs-Rdd*pathX[depth];
                const double di=res*res;
                augPedStack[depth]=(depth==nRealTx-1)?di:augPedStack[depth+1]+di;
                assignedSqStack[depth]=(depth==nRealTx-1)?pathX[depth]*pathX[depth]:assignedSqStack[depth+1]+pathX[depth]*pathX[depth];
                break;
            }
            if(depth==nRealTx-1)goto done;++depth;
        }
    }
done:;

    /* De-permute bits: permuted layer pk -> original layer layerPerm[pk] */
    /* De-permute bits: permuted layer pk -> original layer layerPerm[pk].
     * I-axis real dim = 2*pk  -> uses bits[]  (b[0],b[2],b[4] for 64QAM)
     * Q-axis real dim = 2*pk+1-> uses bitsQ[] (b[1],b[3],b[5] for 64QAM)
     * Output interleaved as [I0,Q0,I1,Q1,I2,Q2] matching nrSymbolModulate. */
    auto bitsFromPerm=[&](const int* idxPerm,uint8_t* bitsOut){
        memset(bitsOut,0,MAX_BITS);
        for(int pk=0;pk<Nt;++pk){
            const int ok=layerPerm[pk],m=pamPerm[pk].mBits;
            const int baseDst=bitOffsOrig[ok];
            for(int k=0;k<m;++k){
                bitsOut[baseDst+2*k]  =pamPerm[pk].bits [idxPerm[2*pk  ]][k]; /* I-axis bit k */
                bitsOut[baseDst+2*k+1]=pamPerm[pk].bitsQ[idxPerm[2*pk+1]][k]; /* Q-axis bit k */
            }
        }
    };

    uint8_t bitsML[MAX_BITS];bitsFromPerm(bestIdx,bitsML);

    /* ---------------------------------------------------------------
     * Soft LLR output
     * For bits where one side (0 or 1) is missing from the list,
     * instead of the fixed fallback lambdaML+2*N0 we compute a
     * nearest-neighbour metric for the missing side:
     *   - find the PAM level closest to the MMSE equalised value
     *     that carries the required bit value
     *   - evaluate its full path metric using the R/Qy already computed
     * This gives a geometry-aware fallback that scales with SNR.
     * --------------------------------------------------------------- */
    if(!isSoft){
        plhs[0]=mxCreateLogicalMatrix(nOutBits,1);
        mxLogical* out=mxGetLogicals(plhs[0]);
        for(int i=0;i<nOutBits;++i)out[i]=(bitsML[i]!=0);
    }else{
        /* Compute MMSE-equalised real vector for fallback NN search */
        double xEq[MAX_REAL_TX]={0.0};
        {
            /* Solve (HR^T HR + N0reg I) xEq = HR^T yR using the same
             * Cholesky path as mmseInit but reuse HR (permuted).
             * Use regularised N0 for numerical stability at low noise. */
            const double N0reg2 = (N0 < 1e-6) ? 1e-6 : N0;
            double A[MAX_REAL_TX*MAX_REAL_TX]={0.0},b_[MAX_REAL_TX]={0.0};
            for(int c=0;c<nRealTx;++c){
                for(int r=0;r<nRealTx;++r){double s=0.0;for(int i=0;i<nRealRx;++i)s+=HR[i+r*nRealRx]*HR[i+c*nRealRx];A[r+c*nRealTx]=s;}
                A[c+c*nRealTx]+=N0reg2;
                double s=0.0;for(int i=0;i<nRealRx;++i)s+=HR[i+c*nRealRx]*yR[i];b_[c]=s;
            }
            double L[MAX_REAL_TX*MAX_REAL_TX]={0.0};
            for(int i=0;i<nRealTx;++i){
                for(int j=0;j<=i;++j){
                    double s=A[i+j*nRealTx];for(int k=0;k<j;++k)s-=L[i+k*nRealTx]*L[j+k*nRealTx];
                    if(i==j)L[i+i*nRealTx]=(s>0.0)?sqrt(s):1e-14;else L[i+j*nRealTx]=s/L[j+j*nRealTx];
                }
            }
            double z[MAX_REAL_TX]={0.0};
            for(int i=0;i<nRealTx;++i){double s=b_[i];for(int k=0;k<i;++k)s-=L[i+k*nRealTx]*z[k];z[i]=s/L[i+i*nRealTx];}
            for(int i=nRealTx-1;i>=0;--i){double s=z[i];for(int k=i+1;k<nRealTx;++k)s-=L[k+i*nRealTx]*xEq[k];xEq[i]=s/L[i+i*nRealTx];}
        }

        double lam0[MAX_BITS],lam1[MAX_BITS];
        for(int i=0;i<nOutBits;++i){lam0[i]=std::numeric_limits<double>::infinity();lam1[i]=std::numeric_limits<double>::infinity();}
        for(int c=0;c<listCount;++c){
            uint8_t bc[MAX_BITS];bitsFromPerm(list[c].idx,bc);
            for(int b=0;b<nOutBits;++b){
                if(bc[b]){if(list[c].ped<lam1[b])lam1[b]=list[c].ped;}
                else{if(list[c].ped<lam0[b])lam0[b]=list[c].ped;}
            }
        }

        /* Nearest-neighbour fallback for missing bit sides */
        int missLam0=0,missLam1=0,missEither=0;
        for(int b=0;b<nOutBits;++b){
            const bool miss0=!mxIsFinite(lam0[b]);
            const bool miss1=!mxIsFinite(lam1[b]);
            if(!miss0 && !miss1) continue;
            ++missEither;
            if(miss0) ++missLam0;
            if(miss1) ++missLam1;

            /* Find which ORIGINAL layer ok this output bit b belongs to,
             * then map to permuted layer pk = fwdPerm[ok].
             * Output bits are in original layer order (bitOffsOrig). */
            int ok_found=-1,bitInLayer=-1;
            {int cum=0;for(int p=0;p<Nt;++p){
                const int nb=2*pamOrig[p].mBits;
                if(b<cum+nb){ok_found=p;bitInLayer=b-cum;break;}
                cum+=nb;
            }}
            if(ok_found<0) continue;
            const int pk=fwdPerm[ok_found];   /* permuted layer index */
            const int dI=2*pk,dQ=2*pk+1;
            /* Output bits are interleaved: [I0,Q0,I1,Q1,I2,Q2,...]
             * Even bitInLayer -> I-axis bit; Odd bitInLayer -> Q-axis bit */
            const int axis   = bitInLayer % 2;
            const int bitPos = bitInLayer / 2;
            const int dAxis  = (axis==0) ? dI : dQ;

            /* For each missing side, find nearest PAM level with that bit value */
            for(int side=0;side<=1;++side){
                if(side==0 && !miss0) continue;
                if(side==1 && !miss1) continue;
                const uint8_t wantBit=(uint8_t)side;
                double bestMetric=std::numeric_limits<double>::infinity();
                for(int p=0;p<pamPerm[pk].nPAM;++p){
                    /* Use correct bit table: I-axis uses bits[], Q-axis uses bitsQ[] */
                    const uint8_t candBit=(axis==0)?pamPerm[pk].bits[p][bitPos]:pamPerm[pk].bitsQ[p][bitPos];
                    if(candBit!=wantBit) continue;
                    /* Build candidate path = bestIdx but replace axis level with p */
                    int tryIdx[MAX_REAL_TX];
                    for(int d=0;d<nRealTx;++d) tryIdx[d]=bestIdx[d];
                    tryIdx[dAxis]=p;
                    /* Evaluate full path metric via R/Qy */
                    double ped_try=0.0;
                    for(int d=nRealTx-1;d>=0;--d){
                        double rhs=Qy[d];
                        for(int j=d+1;j<nRealTx;++j) rhs-=R[d+j*nRealTx]*pamPerm[j/2].levels[tryIdx[j]];
                        const double res=rhs-R[d+d*nRealTx]*pamPerm[d/2].levels[tryIdx[d]];
                        ped_try+=res*res;
                    }
                    if(useQrAugmentation){
                        for(int d=0;d<nRealTx;++d){
                            const double x=pamPerm[d/2].levels[tryIdx[d]];
                            ped_try-=N0*x*x;
                        }
                    }
                    if(ped_try<bestMetric) bestMetric=ped_try;
                }
                if(side==0) lam0[b]=bestMetric;
                else        lam1[b]=bestMetric;
            }
        }

        double sumAbsLLR=0.0;
        plhs[0]=mxCreateDoubleMatrix(nOutBits,1,mxREAL);
        double* out=mxGetPr(plhs[0]);
        for(int b=0;b<nOutBits;++b){
            /* Final safety: if NN fallback still infinite use lambdaML+2N0 */
            if(!mxIsFinite(lam0[b])) lam0[b]=lambdaML+2.0*N0;
            if(!mxIsFinite(lam1[b])) lam1[b]=lambdaML+2.0*N0;
            out[b]=lam1[b]-lam0[b];
            sumAbsLLR+=fabs(out[b]);
        }

        if(nlhs>2){
            const char* fields[]={
                "listCount","nVisitedNodes","missLam0","missLam1",
                "missEither","meanAbsLLR","lambdaML","worstListPed",
                "nCandPerLevel","maxList"};
            plhs[2]=mxCreateStructMatrix(1,1,10,fields);
            mxSetField(plhs[2],0,"listCount",mxCreateDoubleScalar((double)listCount));
            mxSetField(plhs[2],0,"nVisitedNodes",mxCreateDoubleScalar((double)nVisitedNodes));
            mxSetField(plhs[2],0,"missLam0",mxCreateDoubleScalar((double)missLam0));
            mxSetField(plhs[2],0,"missLam1",mxCreateDoubleScalar((double)missLam1));
            mxSetField(plhs[2],0,"missEither",mxCreateDoubleScalar((double)missEither));
            mxSetField(plhs[2],0,"meanAbsLLR",mxCreateDoubleScalar(sumAbsLLR/(double)nOutBits));
            mxSetField(plhs[2],0,"lambdaML",mxCreateDoubleScalar(lambdaML));
            mxSetField(plhs[2],0,"worstListPed",mxCreateDoubleScalar((listCount>0)?worstListPed:mxGetInf()));
            mxSetField(plhs[2],0,"nCandPerLevel",mxCreateDoubleScalar((double)nCandPerLevel));
            mxSetField(plhs[2],0,"maxList",mxCreateDoubleScalar((double)maxList));
        }
    }
    if(nlhs>1)plhs[1]=mxCreateDoubleScalar((double)nVisitedNodes);
}
