function channel = create_cdl_channel(cfg, sample_rate)
%CREATECDLCHANNEL Create and configure CDL channel object.

rng(cfg.simulation.rngSeed);
if cfg.channel.randomizeUtDirectionOfTravel
    lo = cfg.channel.randomUtDirectionOfTravel(:, 1);
    up = cfg.channel.randomUtDirectionOfTravel(:, 2);
    value = lo + (up - lo) .* rand(size(lo));
    cfg.channel.utDirectionOfTravel = reshape(value, size(cfg.channel.utDirectionOfTravel));
end
if cfg.channel.randomizeMeanAngles
    lo = cfg.channel.randomMeanAngles(:, 1);
    up = cfg.channel.randomMeanAngles(:, 2);
    value = lo + (up - lo) .* rand(size(lo));
    cfg.channel.meanAngles = reshape(value, size(cfg.channel.meanAngles));
end
if cfg.channel.randomizeTransmitArrayOrientation
    lo = cfg.channel.randomTransmitArrayOrientation(:, 1);
    up = cfg.channel.randomTransmitArrayOrientation(:, 2);
    value = lo + (up - lo) .* rand(size(lo));
    cfg.channel.transmitArrayOrientation = reshape(value, size(cfg.channel.transmitArrayOrientation));
end
if cfg.channel.randomizeReceiveArrayOrientation
    lo = cfg.channel.randomReceiveArrayOrientation(:, 1);
    up = cfg.channel.randomReceiveArrayOrientation(:, 2);
    value = lo + (up - lo) .* rand(size(lo));
    cfg.channel.receiveArrayOrientation = reshape(value, size(cfg.channel.receiveArrayOrientation));
end

channel = nrCDLChannel;
channel.DelayProfile = char(cfg.channel.delayProfile);
channel.DelaySpread = cfg.channel.delaySpread;
channel.MaximumDopplerShift = cfg.channel.maximumDopplerHz;
channel.SampleRate = sample_rate;
channel.CarrierFrequency = cfg.channel.carrierFrequency;
channel.UTDirectionOfTravel = cfg.channel.utDirectionOfTravel;
channel.AngleScaling = cfg.channel.angleScaling;
if cfg.channel.angleScaling
    channel.MeanAngles = cfg.channel.meanAngles;
end
channel.TransmitAntennaArray.Size = cfg.channel.transmitAntennaArray.size;
channel.TransmitAntennaArray.ElementSpacing = cfg.channel.transmitAntennaArray.elementSpacing;
channel.TransmitAntennaArray.PolarizationAngles = cfg.channel.transmitAntennaArray.polarizationAngles;
channel.TransmitAntennaArray.Element = char(cfg.channel.transmitAntennaArray.element);
channel.TransmitAntennaArray.PolarizationModel = char(cfg.channel.transmitAntennaArray.polarizationModel);
channel.TransmitArrayOrientation = cfg.channel.transmitArrayOrientation;
channel.ReceiveAntennaArray.Size = cfg.channel.receiveAntennaArray.size;
channel.ReceiveAntennaArray.ElementSpacing = cfg.channel.receiveAntennaArray.elementSpacing;
channel.ReceiveAntennaArray.PolarizationAngles = cfg.channel.receiveAntennaArray.polarizationAngles;
channel.ReceiveAntennaArray.Element = char(cfg.channel.receiveAntennaArray.element);
channel.ReceiveAntennaArray.PolarizationModel = char(cfg.channel.receiveAntennaArray.polarizationModel);
channel.ReceiveArrayOrientation = cfg.channel.receiveArrayOrientation;
channel.NormalizePathGains = cfg.channel.normalizePathGains;
channel.NormalizeChannelOutputs = cfg.channel.normalizeOutputs;
channel.RandomStream = 'mt19937ar with seed';
channel.Seed = cfg.simulation.rngSeed + 17;

if cfg.channel.angleScaling
    switch channel.DelayProfile
        case 'CDL-A'
            % channel.MeanAngles = [-2.0538, -164.4029, 97.2731, 87.6845];
            channel.AngleSpreads = [71.0345, 86.5739, 28.3115, 20.8759];
        case 'CDL-B'
            % channel.MeanAngles = [-4.9614, 176.6051, 105.6415, 71.7628];
            channel.AngleSpreads = [41.9923, 60.1122, 5.9616, 10.3884];
        case 'CDL-C'
            % channel.MeanAngles = [-19.6808, 149.8943, 99.3310, 73.4974];
            channel.AngleSpreads = [37.4036, 71.4535, 4.0665, 10.4182];
        case 'CDL-D'
            % channel.MeanAngles = [1.9860, 178.2103, 98.0902, 81.5213];
            channel.AngleSpreads = [14.3881, 15.6059, 2.4451, 1.5375];
        case 'CDL-E'
            % channel.MeanAngles = [2.8118, 179.2669, 99.7943, 80.5305];
            channel.AngleSpreads = [12.4060, 27.4601, 1.4136, 2.3815];
    end
end

if cfg.channel.swapTransmitAndReceive
    swapTransmitAndReceive(channel);
end

end
