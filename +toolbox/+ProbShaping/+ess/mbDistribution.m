function probabilities = mbDistribution(ask_size, nuMb, mode)
%MBDISTRIBUTION Maxwell-Boltzmann probability mass function over an ASK alphabet.
if nargin<3
    mode='PAM';
end
switch mode

    case 'PAM'
        ask_constellation = 2 * (1:ask_size) - mean(2 * (1:ask_size));
        probabilities = exp(-nuMb * (ask_constellation(:) .^ 2));
        probabilities = probabilities / sum(probabilities);

    case 'Amplitude'

        ask_constellation = 1:2:2*ask_size-1; 
        probabilities = exp(-nuMb * (ask_constellation(:) .^ 2));
        probabilities = probabilities / sum(probabilities);

end


end