classdef warmup_accumulator
%WARMUP_ACCUMULATOR Per-SNR-point warmup SINR accumulator for AMC.
%

methods (Static)

    function w = reset(state)
    %RESET Fresh accumulator for one SNR point.
        w = struct( ...
            'timeDomainSum', zeros(state.numLayers, 1), ...
            'timeDomain',    state.timeDomain, ...
            'count',         0);
    end

    function w = add(w, layer_snr_db)
    %ADD Accumulate one warmup block's measurement.
        switch w.timeDomain
            case 'db'
                w.timeDomainSum = w.timeDomainSum + layer_snr_db;
            case 'capacity'
                layer_snr_lin = 10 .^ (layer_snr_db / 10);
                w.timeDomainSum = w.timeDomainSum + log2(1 + layer_snr_lin);
            otherwise
                error('toolbox:amc:InvalidTimeAveragingDomain', ...
                    'Unknown AMC time averaging domain "%s".', w.timeDomain);
        end
        w.count = w.count + 1;
    end

end
end
