function channel = create_tdl_channel(cfg, num_transmit_antennas, sample_rate)
%CREATETDLCHANNEL Create and configure TDL channel object.

channel = nrTDLChannel;
channel.DelayProfile = char(cfg.channel.delayProfile);
channel.DelaySpread = cfg.channel.delaySpread;
channel.MaximumDopplerShift = cfg.channel.maximumDopplerHz;
channel.SampleRate = sample_rate;
channel.NumTransmitAntennas = num_transmit_antennas;
channel.NumReceiveAntennas = cfg.channel.numReceiveAntennas;
channel.NormalizePathGains = cfg.channel.normalizePathGains;
channel.NormalizeChannelOutputs = cfg.channel.normalizeOutputs;
channel.RandomStream = 'mt19937ar with seed';
channel.Seed = cfg.simulation.rngSeed + 17;
end
