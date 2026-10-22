function [codebook] = XOR_Codebook(max_g,n,type,mode)
% max_g: Number of entries to select from the Codebook (i.e., max_g=2^K-2, where K is the number of feedback bits)
% n: Number of CBs in the TB
% type: 1 --> Codebook 1; 2 --> Codebook 2
% mode: 1 --> Subset selection based on the first max_g entries (entries with the smallest number of CB sets);
% 2--> Subset selection is based on non-uniform subsampling (better performance but still based on a fixed rule/formula)
if type==2 && mode==1
    for g=1:max_g
        codebook{g}=ConsecutiveCBs_entry(g,n);
    end
elseif type==1 && mode==1
    for g=1:max_g
        for i=1:g
            codebook{g}{i}=i:g:n;
        end
    end
elseif type==2 && mode==2
    a=floor(2*n/((max_g+1)*(max_g+2)));
    if a>0 % non-uniform subsampling
        for j=1:max_g
            g=a*(j*(j+1)/2);
            codebook{j}=ConsecutiveCBs_entry(g,n);
        end
    else % non-uniform subsampling + fallback to mode 1
        a=1;
        availble=1:n-1;
        for j=1:max_g
            g=a*(j*(j+1)/2);
            if g<n
                availble(availble==g)=[];
            else % fallback to mode 1 for remaining entries
                g=availble(1);
                availble(availble==g)=[];
            end
            codebook{j}=ConsecutiveCBs_entry(g,n);
        end
    end
elseif type==1 && mode==2
    a=floor(2*n/((max_g+1)*(max_g+2)));
    if a>0 % non-uniform subsampling
        for j=1:max_g
            g=a*(j*(j+1)/2);
            for i=1:g
                codebook{j}{i}=i:g:n;
            end
        end
    else % non-uniform subsampling + fallback to mode 1
        a=1;
        availble=1:n-1;
        for j=1:max_g
            g=a*(j*(j+1)/2);
            if g<n
                availble(availble==g)=[];
            else % fallback to mode 1 for remaining entries
                g=availble(1);
                availble(availble==g)=[];
            end
            for i=1:g
                codebook{j}{i}=i:g:n;
            end
        end
    end
end

end


function [entry] = ConsecutiveCBs_entry(g,n) %used for Codebook 2
    numCBs1=ceil(n/g);
    numCBs2=floor(n/g);
    r=mod(n,g);
    startCB=1;
    for i=1:r
        entry{i}=startCB:startCB+numCBs1-1;
        startCB=startCB+numCBs1;
    end
    for i=r+1:g
        entry{i}=startCB:startCB+numCBs2-1;
        startCB=startCB+numCBs2;
    end
end
